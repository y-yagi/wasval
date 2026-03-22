# frozen_string_literal: true

module Wasval
  class Config
    DEFAULT_TIMEOUT = 5
    DEFAULT_MEMORY_LIMIT = 64

    attr_accessor :timeout, :memory_limit

    def initialize
      @timeout = DEFAULT_TIMEOUT
      @memory_limit = DEFAULT_MEMORY_LIMIT
    end
  end
end
