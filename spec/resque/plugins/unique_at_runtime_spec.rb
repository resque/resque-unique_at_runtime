# frozen_string_literal: true

require "spec_helper"

class SerialJob
  include Resque::Plugins::UniqueAtRuntime

  @queue = :serial_work

  def self.perform(*args)
  end
end

class SerialJobWithCustomRedisKey
  include Resque::Plugins::UniqueAtRuntime

  @queue = :serial_work

  def self.unique_at_runtime_redis_key(account_id, *_args)
    "unique_at_runtime:#{@queue}:#{account_id}"
  end

  def self.perform(account_id, *args)
  end
end

describe Resque::Plugins::UniqueAtRuntime do
  before do
    Resque.redis.flushdb
  end

  describe ".runtime_requeue_interval" do
    before do
      Resque::UniqueAtRuntime.configuration.requeue_interval = 1
      SerialJob.remove_instance_variable(:@runtime_requeue_interval) if SerialJob.instance_variable_defined?(:@runtime_requeue_interval)
    end

    it "defaults to 1" do
      expect(SerialJob.runtime_requeue_interval).to eql(1)
    end

    it "is overridable with a class instance var" do
      SerialJob.instance_variable_set(:@runtime_requeue_interval, 5)
      expect(SerialJob.runtime_requeue_interval).to eql(5)
    end
  end

  describe ".runtime_lock_timeout" do
    before do
      Resque::UniqueAtRuntime.configuration.lock_timeout = 10
      SerialJob.remove_instance_variable(:@runtime_lock_timeout) if SerialJob.instance_variable_defined?(:@runtime_lock_timeout)
    end

    it "uses the configured timeout" do
      expect(SerialJob.runtime_lock_timeout).to eql(10)
      expect(SerialJob.runtime_lock_timeout_at(100)).to eql(111)
    end

    it "is overridable with a class instance var" do
      SerialJob.instance_variable_set(:@runtime_lock_timeout, 5)

      expect(SerialJob.runtime_lock_timeout).to eql(5)
    end
  end

  describe ".unique_at_runtime_key_base" do
    before do
      Resque::UniqueAtRuntime.configuration.unique_at_runtime_key_base = "runtime-keys"
      SerialJob.remove_instance_variable(:@unique_at_runtime_key_base) if SerialJob.instance_variable_defined?(:@unique_at_runtime_key_base)
    end

    it "uses the configured key base" do
      expect(SerialJob.unique_at_runtime_key_base).to eql("runtime-keys")
    end

    it "is overridable with a class instance var" do
      SerialJob.instance_variable_set(:@unique_at_runtime_key_base, "custom-runtime-keys")

      expect(SerialJob.unique_at_runtime_key_base).to eql("custom-runtime-keys")
    end
  end

  describe ".can_lock_queue?" do
    before do
      Resque::UniqueAtRuntime.configuration.lock_timeout = Resque::UniqueAtRuntime::Configuration::DEFAULT_LOCK_TIMEOUT
      SerialJob.remove_instance_variable(:@runtime_lock_timeout) if SerialJob.instance_variable_defined?(:@runtime_lock_timeout)
    end

    it "can lock a queue" do
      expect(SerialJob.can_lock_queue?(:serial_work)).to eql(true)
    end

    it "cannot lock an already locked queue" do
      expect(SerialJob.can_lock_queue?(:serial_work)).to eql(true)
      expect(SerialJob.can_lock_queue?(:serial_work)).to eql(false)
    end

    it "cannot lock a queue with active lock" do
      expect(SerialJob.can_lock_queue?(:serial_work)).to eql(true)
      Timecop.travel(Date.today + 1) do
        expect(SerialJob.can_lock_queue?(:serial_work)).to eql(false)
      end
    end

    it "can relock a queue with expired lock" do
      expect(SerialJob.can_lock_queue?(:serial_work)).to eql(true)

      Timecop.travel(Date.today + 10) do
        expect(SerialJob.can_lock_queue?(:serial_work)).to eql(true)
      end
    end

    it "solves race condition with getset" do
      expect(SerialJob.can_lock_queue?(:serial_work)).to eql(true)

      Timecop.travel(Date.today + 10) do
        threads = (1..10).to_a.map do
          Thread.new do
            Thread.current[:locked] = SerialJob.can_lock_queue?(:serial_work)
          end
        end

        # Only one worker should acquire lock
        locks = threads.map { |t|
          t.join
          t[:locked]
        }
        expect(locks.count(true)).to eql(1)
      end
    end
  end

  describe ".unlock_queue" do
    before do
      SerialJob.remove_instance_variable(:@unlock_queue_executed) if SerialJob.instance_variable_defined?(:@unlock_queue_executed)
      SerialJob.can_lock_queue?(:serial_work)
    end

    it "removes the lock and ignores duplicate unlocks" do
      SerialJob.unlock_queue(:serial_work)

      expect(Resque.redis.hget(SerialJob.unique_at_runtime_key_base, SerialJob.unique_at_runtime_redis_key(:serial_work))).to be_nil
      expect { SerialJob.unlock_queue(:serial_work) }.not_to raise_error
    end
  end

  describe ".around_perform_unlock_runtime" do
    it "unlocks when the wrapped operation raises" do
      SerialJob.can_lock_queue?(:serial_work)

      expect do
        SerialJob.around_perform_unlock_runtime(:serial_work) { raise "failure" }
      end.to raise_error("failure")

      expect(Resque.redis.hget(SerialJob.unique_at_runtime_key_base, SerialJob.unique_at_runtime_redis_key(:serial_work))).to be_nil
    end
  end

  describe ".on_failure_unlock_runtime" do
    it "unlocks a failed job" do
      SerialJob.remove_instance_variable(:@unlock_queue_executed) if SerialJob.instance_variable_defined?(:@unlock_queue_executed)
      SerialJob.can_lock_queue?(:serial_work)

      SerialJob.on_failure_unlock_runtime(:serial_work)

      expect(Resque.redis.hget(SerialJob.unique_at_runtime_key_base, SerialJob.unique_at_runtime_redis_key(:serial_work))).to be_nil
    end
  end

  describe "Resque.running?" do
    it "delegates to the job lock check" do
      expect(Resque.running?(SerialJob, :serial_work)).to be(false)
    end
  end

  describe ".perform" do
    before do
      SerialJob.instance_variable_set(:@runtime_requeue_interval, 0)
    end

    describe "using the default redis key" do
      it "locks and unlock the queue" do
        job = Resque::Job.new(:serial_work, "class" => "SerialJob", "args" => %w[account_one job_one])

        # job is the first SerialJob to run so it can lock the queue and perform
        expect(SerialJob).to receive(:queue_locked?).and_return(false)

        # but it should also clean up after itself
        expect(SerialJob).to receive(:unlock_queue)

        job.perform
      end

      it "cleans up lock even with catastrophic job failure" do
        job = Resque::Job.new(:serial_work, "class" => "SerialJob", "args" => %w[account_one job_one])

        # job is the first SerialJob to run so it can lock the queue and perform
        expect(SerialJob).to receive(:queue_locked?).and_return(false)

        # but we have a catastrophic job failure
        expect(SerialJob).to receive(:perform).and_raise(Exception)

        # and still it should clean up after itself
        expect(SerialJob).to receive(:unlock_queue).at_least(:once)

        # unfortunately, the job will be lost but resque doesn't guarantee jobs
        # aren't lost
        expect { job.perform }.to raise_error(Exception)
      end

      it "places self at the end of the queue if unable to acquire the lock" do
        job1_payload = %w[account_one job_one]
        job2_payload = %w[account_one job_two]
        Resque::Job.create(:serial_work, "SerialJob", job1_payload)
        Resque::Job.create(:serial_work, "SerialJob", job2_payload)

        expect(SerialJob).to receive(:queue_locked?).and_return(true)

        # perform returns false when DontPerform exception is raised in
        # before_perform callback
        job1 = Resque.reserve(:serial_work)
        expect(job1.perform).to eql(false)

        first_queue_element = Resque.reserve(:serial_work)
        expect(first_queue_element.payload["args"]).to eql([job2_payload])
      end
    end

    describe "with a custom unique_at_runtime_redis_key" do
      it "locks and unlock the queue" do
        job = Resque::Job.new(:serial_work, "class" => "SerialJobWithCustomRedisKey", "args" => %w[account_one job_one])

        # job is the first SerialJobWithCustomRedisKey to run so it can lock the queue and perform
        expect(SerialJobWithCustomRedisKey).to receive(:queue_locked?).and_return(false)

        # but it should also clean up after itself
        expect(SerialJobWithCustomRedisKey).to receive(:unlock_queue)

        job.perform
      end

      it "cleans up lock even with catastrophic job failure" do
        job = Resque::Job.new(:serial_work, "class" => "SerialJobWithCustomRedisKey", "args" => %w[account_one job_one])

        # job is the first SerialJobWithCustomRedisKey to run so it can lock the queue and perform
        expect(SerialJobWithCustomRedisKey).to receive(:queue_locked?).and_return(false)

        # but we have a catastrophic job failure
        expect(SerialJobWithCustomRedisKey).to receive(:perform).and_raise(Exception)

        # and still it should clean up after itself
        expect(SerialJobWithCustomRedisKey).to receive(:unlock_queue).at_least(:once)

        # unfortunately, the job will be lost but resque doesn't guarantee jobs
        # aren't lost
        expect { job.perform }.to raise_error(Exception)
      end

      it "places self at the end of the queue if unable to acquire the lock" do
        job1_payload = %w[account_one job_one]
        job2_payload = %w[account_one job_two]
        Resque::Job.create(:serial_work, "SerialJobWithCustomRedisKey", job1_payload)
        Resque::Job.create(:serial_work, "SerialJobWithCustomRedisKey", job2_payload)

        expect(SerialJobWithCustomRedisKey).to receive(:queue_locked?).and_return(true)

        # perform returns false when DontPerform exception is raised in
        # before_perform callback
        job1 = Resque.reserve(:serial_work)
        expect(job1.perform).to eql(false)

        first_queue_element = Resque.reserve(:serial_work)
        expect(first_queue_element.payload["args"]).to eql([job2_payload])
      end
    end
  end
end
