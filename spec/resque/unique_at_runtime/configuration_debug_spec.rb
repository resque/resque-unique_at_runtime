# frozen_string_literal: true

require "spec_helper"

RSpec.describe Resque::UniqueAtRuntime::Configuration do
  include_context "with stubbed env"

  # rubocop:disable RSpec/MultipleExpectations
  it "initializes a logger and enables debug mode from RESQUE_DEBUG" do
    stub_env("RESQUE_DEBUG" => "runtime")
    configuration = described_class.send(:allocate)
    configuration.send(:initialize)

    expect(configuration.logger).to be_a(Logger)
    expect(configuration.debug_mode).to be(true)
  end
  # rubocop:enable RSpec/MultipleExpectations
end
