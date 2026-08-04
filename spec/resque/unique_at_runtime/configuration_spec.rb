# frozen_string_literal: true

require "spec_helper"

describe Resque::UniqueAtRuntime::Configuration do
  context "logging" do
    let(:log_level) { :info }
    let(:logger) { Logger.new("/dev/null") }
    let(:unique_at_runtime_key_base) { "unicorns" }
    let(:lock_timeout) { 1000 }
    let(:requeue_interval) { 3 }
    let(:debug_mode) { nil }
    let(:instance) { described_class.instance }

    before do
      @logger = described_class.instance.logger
      @log_level = described_class.instance.log_level
      @unique_at_runtime_key_base = described_class.instance.unique_at_runtime_key_base
      @lock_timeout = described_class.instance.lock_timeout
      @requeue_interval = described_class.instance.requeue_interval
      @debug_mode = described_class.instance.debug_mode

      described_class.instance.logger = logger
      described_class.instance.log_level = log_level
      described_class.instance.unique_at_runtime_key_base = unique_at_runtime_key_base
      described_class.instance.lock_timeout = lock_timeout
      described_class.instance.requeue_interval = requeue_interval
      described_class.instance.debug_mode = debug_mode
    end

    after do
      described_class.instance.logger = @logger
      described_class.instance.log_level = @log_level
      described_class.instance.unique_at_runtime_key_base = @unique_at_runtime_key_base
      described_class.instance.lock_timeout = @lock_timeout
      described_class.instance.requeue_interval = @requeue_interval
      described_class.instance.debug_mode = @debug_mode
    end

    describe "#initialize" do
      subject { instance }

      it "does not raise" do
        block_is_expected.not_to raise_error
      end

      context "logger option" do
        subject { instance.logger }

        it "sets logger" do
          expect(subject).to eq(logger)
        end
      end

      context "log_level option" do
        subject { instance.log_level }

        it "sets log_level" do
          expect(subject).to eq(log_level)
        end
      end

      context "unique_at_runtime_key_base option" do
        subject { instance.unique_at_runtime_key_base }

        it "sets unique_at_runtime_key_base" do
          expect(subject).to eq(unique_at_runtime_key_base)
        end
      end

      context "lock_timeout option" do
        subject { instance.lock_timeout }

        it "sets lock_timeout" do
          expect(subject).to eq(lock_timeout)
        end
      end

      context "requeue_interval option" do
        subject { instance.requeue_interval }

        it "sets requeue_interval" do
          expect(subject).to eq(requeue_interval)
        end
      end

      context "debug_mode option" do
        subject { instance.debug_mode }

        it "sets debug_mode" do
          expect(subject).to be(false)
        end

        context "value giving truthy" do
          let(:debug_mode) { "truthy" }

          it "can be set" do
            expect(subject).to be(true)
          end
        end

        context "value giving falsey" do
          let(:debug_mode) { false }

          it "can be set" do
            expect(subject).to be(false)
          end
        end
      end
    end

    describe "#to_hash" do
      subject { instance.to_hash }

      it("does not raise") do
        block_is_expected.not_to raise_error
      end

      it("returns a hash") do
        expect(subject).to eq({
          debug_mode: false, # normalized to true || false
          lock_timeout: lock_timeout,
          log_level: :info,
          logger: logger,
          requeue_interval: requeue_interval,
          unique_at_runtime_key_base: unique_at_runtime_key_base
        })
      end
    end

    context "when RESQUE_DEBUG enables runtime logging" do
      include_context "with stubbed env"

      it "initializes a logger" do
        stub_env("RESQUE_DEBUG" => "runtime")
        configuration = described_class.send(:allocate)
        configuration.send(:initialize)

        expect(configuration.debug_mode).to be(true)
        expect(configuration.logger).to be_a(Logger)
      end
    end
  end
end
