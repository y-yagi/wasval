# frozen_string_literal: true

require_relative "wasval/version"
require_relative "wasval/config"
require_relative "wasval/result"
require_relative "wasval/executor"
require_relative "wasval/install/ruby_wasm"

module Wasval
  class Error < StandardError; end

  class << self
    def execute(code, timeout: nil, memory_limit: nil)
      resolved_timeout = timeout || config.timeout
      resolved_memory = memory_limit || config.memory_limit

      executor.execute(code: code, timeout: resolved_timeout, memory_limit: resolved_memory)
    end

    def configure
      yield config
    end

    def config
      @config ||= Config.new
    end

    def executor
      @executor ||= Executor.new
    end
  end
end
