# frozen_string_literal: true

require "wasmtime"

module Wasval
  class Executor
    STDOUT_BUFFER_SIZE = 10 * 1024 * 1024  # 10 MB
    STDERR_BUFFER_SIZE = 1 * 1024 * 1024   # 1 MB
    WASM_PATH = ENV["WASVAL_RUBY_WASM_PATH"]

    def initialize
      raise ArgumentError.new "Please specify 'WASVAL_RUBY_WASM_PATH' env" if WASM_PATH.nil?

      @engine = Wasmtime::Engine.new(epoch_interruption: true)
      @mod = Wasmtime::Module.from_file(@engine, WASM_PATH)
    end

    def execute(code:, timeout:, memory_limit:)
      if code.nil? || code.strip.empty?
        return Result.new(
          status: :sandbox_error,
          output: "",
          stderr: "",
          error_message: "code must not be nil or empty"
        )
      end

      stdout_buf = +""
      stderr_buf = +""

      wasi_config = Wasmtime::WasiConfig.new
        .set_argv(["ruby", "-"])
        .set_stdin_string(wrapped_code(code))
        .set_stdout_buffer(stdout_buf, STDOUT_BUFFER_SIZE)
        .set_stderr_buffer(stderr_buf, STDERR_BUFFER_SIZE)

      store = Wasmtime::Store.new(@engine,
        wasi_p1_config: wasi_config,
        limits: { memory_size: memory_limit * 1024 * 1024 }
      )
      store.set_epoch_deadline(timeout)

      linker = Wasmtime::Linker.new(@engine)
      Wasmtime::WASI::P1.add_to_linker_sync(linker)

      @engine.start_epoch_interval(1000)

      begin
        linker.instantiate(store, @mod).invoke("_start")
        classify_output(stdout_buf, stderr_buf, store)
      rescue Wasmtime::WasiExit
        classify_output(stdout_buf, stderr_buf, store)
      rescue Wasmtime::Trap => e
        if e.code == :interrupt
          Result.new(status: :timeout, output: stdout_buf, stderr: "", error_message: "execution timed out")
        elsif store.linear_memory_limit_hit?
          Result.new(status: :memory_limit, output: stdout_buf, stderr: "", error_message: "memory limit exceeded")
        else
          Result.new(status: :sandbox_error, output: stdout_buf, stderr: stderr_buf, error_message: e.message)
        end
      rescue Wasmtime::Error => e
        if store.linear_memory_limit_hit?
          Result.new(status: :memory_limit, output: stdout_buf, stderr: "", error_message: "memory limit exceeded")
        else
          Result.new(status: :sandbox_error, output: stdout_buf, stderr: stderr_buf, error_message: e.message)
        end
      rescue => e
        Result.new(status: :sandbox_error, output: stdout_buf, stderr: stderr_buf, error_message: e.message)
      end
    end

    private

    def wrapped_code(code)
      <<~RUBY
        begin
          eval(#{code.inspect}, binding, "(user_code)", 1)
        rescue SyntaxError => e
          $stderr.print "WASVAL:syntax_error:\#{e.message}"
          exit 1
        rescue => e
          $stderr.print "WASVAL:runtime_error:\#{e.class}:\#{e.message}"
          exit 1
        end
      RUBY
    end

    def classify_output(stdout, stderr, store)
      if store.linear_memory_limit_hit?
        return Result.new(status: :memory_limit, output: stdout, stderr: "", error_message: "memory limit exceeded")
      end

      if (match = stderr.match(/WASVAL:syntax_error:(.+)/m))
        clean_stderr = stderr.gsub(/^WASVAL:.*$/, "").strip
        Result.new(status: :syntax_error, output: stdout, stderr: clean_stderr, error_message: match[1].strip)
      elsif (match = stderr.match(/WASVAL:runtime_error:([^:]+):(.+)/m))
        clean_stderr = stderr.gsub(/^WASVAL:.*$/, "").strip
        error_msg = "#{match[1]}: #{match[2].strip}"
        Result.new(status: :runtime_error, output: stdout, stderr: clean_stderr, error_message: error_msg)
      elsif stderr.match?(/cannot load such file/)
        Result.new(status: :runtime_error, output: stdout, stderr: stderr, error_message: stderr)
      else
        Result.new(status: :success, output: stdout, stderr: stderr, error_message: nil)
      end
    end
  end
end
