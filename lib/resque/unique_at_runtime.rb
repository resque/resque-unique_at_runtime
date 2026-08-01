# frozen_string_literal: true

require "version_gem"
require_relative "unique_at_runtime/version"

module Resque
  module UniqueAtRuntime
  end
end

Resque::UniqueAtRuntime::Version.class_eval do
  extend VersionGem::Basic
end
