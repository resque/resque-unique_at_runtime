# frozen_string_literal: true

require "spec_helper"

describe Resque::UniqueAtRuntime do
  let(:unique_log_level) { :info }
  let(:logger) { Logger.new("/dev/null") }

  describe ".log" do
    subject { described_class.log("warbler") }

    before do
      @logger = Resque::UniqueAtRuntime.configuration.logger
      @log_level = Resque::UniqueAtRuntime.configuration.log_level
      Resque::UniqueAtRuntime.configuration.logger = logger
      Resque::UniqueAtRuntime.configuration.log_level = :info
    end

    after do
      Resque::UniqueAtRuntime.configuration.logger = @logger
      Resque::UniqueAtRuntime.configuration.log_level = @log_level
    end

    it("logs") do
      expect(logger).to receive(:info).with("warbler")
      block_is_expected.not_to raise_error
    end

    it "does nothing without a logger" do
      Resque::UniqueAtRuntime.configuration.logger = nil

      expect { described_class.log("warbler") }.not_to raise_error
    end
  end

  describe ".debug" do
    context "with debug_mode => true" do
      subject { described_class.debug("warbler") }

      before do
        @debug_mode = Resque::UniqueAtRuntime.configuration.debug_mode
        @logger = Resque::UniqueAtRuntime.configuration.logger
        @log_level = Resque::UniqueAtRuntime.configuration.log_level
        Resque::UniqueAtRuntime.configuration.debug_mode = true
        Resque::UniqueAtRuntime.configuration.logger = logger
        Resque::UniqueAtRuntime.configuration.log_level = :info
      end

      after do
        Resque::UniqueAtRuntime.configuration.debug_mode = @debug_mode
        Resque::UniqueAtRuntime.configuration.logger = @logger
        described_class.configuration.log_level = @log_level
      end

      it("logs") do
        expect(logger).to receive(:debug).with(/R-UAR.*warbler/)
        block_is_expected.not_to raise_error
      end
    end

    context 'with ENV["RESQUE_DEBUG"] = "runtime"', :env_resque_stubbed do
      subject { described_class.debug("warbler") }

      let(:resque_debug) { "runtime" }

      before do
        @debug_mode = Resque::UniqueAtRuntime.configuration.debug_mode
        @logger = Resque::UniqueAtRuntime.configuration.logger
        @log_level = Resque::UniqueAtRuntime.configuration.log_level
        Resque::UniqueAtRuntime.configuration.logger = logger
        Resque::UniqueAtRuntime.configuration.log_level = :info
        Resque::UniqueAtRuntime.configuration.send(:debug_mode_from_env)
      end

      after do
        Resque::UniqueAtRuntime.configuration.debug_mode = @debug_mode
        Resque::UniqueAtRuntime.configuration.logger = @logger
        Resque::UniqueAtRuntime.configuration.log_level = @log_level
      end

      it("logs") do
        expect(logger).to receive(:debug).with(/R-UAR.*warbler/)
        block_is_expected.not_to raise_error
      end
    end

    context 'with ENV["RESQUE_DEBUG"] = nil', :env_resque_stubbed do
      subject { described_class.debug("warbler") }

      let(:resque_debug) { nil }

      before do
        @debug_mode = Resque::UniqueAtRuntime.configuration.debug_mode
        @logger = Resque::UniqueAtRuntime.configuration.logger
        @log_level = Resque::UniqueAtRuntime.configuration.log_level
        Resque::UniqueAtRuntime.configuration.logger = logger
        Resque::UniqueAtRuntime.configuration.log_level = :info
        Resque::UniqueAtRuntime.configuration.send(:debug_mode_from_env)
      end

      after do
        Resque::UniqueAtRuntime.configuration.debug_mode = @debug_mode
        Resque::UniqueAtRuntime.configuration.logger = @logger
        Resque::UniqueAtRuntime.configuration.log_level = @log_level
      end

      it("does not logs") do
        expect(logger).not_to receive(:debug)
        block_is_expected.not_to raise_error
      end

      it "does nothing without a logger" do
        described_class.configuration.logger = nil

        expect { described_class.debug("warbler") }.not_to raise_error
      end
    end

    context "with debug_mode => true and no logger" do
      around do |example|
        configuration = described_class.configuration
        original_debug_mode = configuration.debug_mode
        original_logger = configuration.logger
        begin
          configuration.debug_mode = true
          configuration.logger = nil
          example.run
        ensure
          configuration.debug_mode = original_debug_mode
          configuration.logger = original_logger
        end
      end

      it "does nothing without a logger" do
        expect { described_class.debug("warbler") }.not_to raise_error
      end
    end
  end
end
