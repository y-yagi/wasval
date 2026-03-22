# frozen_string_literal: true

module Wasval
  class Result
    VALID_STATUSES = %i[success syntax_error runtime_error timeout memory_limit sandbox_error].freeze

    attr_reader :status, :output, :stderr, :error_message

    def initialize(status:, output:, stderr:, error_message:)
      raise ArgumentError, "invalid status: #{status}" unless VALID_STATUSES.include?(status)

      @status = status
      @output = output.to_s
      @stderr = stderr.to_s
      @error_message = error_message

      freeze
    end

    def success?
      @status == :success
    end

    def timeout?
      @status == :timeout
    end

    def error_type
      return nil if @status == :success

      @status
    end
  end
end
