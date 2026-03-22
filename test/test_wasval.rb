# frozen_string_literal: true

require "test_helper"

class TestWasval < Minitest::Test
  def test_execute_returns_result
    result = Wasval.execute("puts 2 + 2")
    assert_instance_of Wasval::Result, result
  end

  def test_execute_captures_stdout
    result = Wasval.execute("puts 'hello wasval'")
    assert result.success?
    assert_equal "hello wasval\n", result.output
  end

  def test_execute_success_has_nil_error_type
    result = Wasval.execute("1 + 1")
    assert result.success?
    assert_nil result.error_type
    assert_nil result.error_message
  end

  def test_execute_output_always_string
    result = Wasval.execute("1 + 1")
    assert_instance_of String, result.output
    assert_instance_of String, result.stderr
  end

  def test_execute_blocked_filesystem_read
    result = Wasval.execute('File.read("/etc/passwd")')
    refute result.success?
  end

  def test_execute_subprocess_spawn
    result = Wasval.execute('system("id")')
    # FIXME: ruby.wasm doesn't block `system` method.
    assert result.success?
    assert result.output.empty?
  end

  def test_execute_blocked_network_access
    # FIXME: This passes because require is failed. Doesn't test blocking network access.
    result = Wasval.execute(<<~RUBY)
      require "net/http"
      Net::HTTP.get(URI("http://example.com"))
    RUBY
    refute result.success?
  end

  def test_execute_syntax_error_returns_result
    result = Wasval.execute("def broken(")
    refute result.success?
    assert_equal :syntax_error, result.error_type
    refute_nil result.error_message
  end

  def test_execute_runtime_error_returns_result
    result = Wasval.execute("raise 'something went wrong'")
    refute result.success?
    assert_equal :runtime_error, result.error_type
    assert_match(/something went wrong/, result.error_message)
  end

  def test_execute_undefined_constant_returns_result
    result = Wasval.execute("UnknownClass.new")
    refute result.success?
    assert_equal :runtime_error, result.error_type
    refute_nil result.error_message
  end

  def test_execute_never_raises
    # None of these should raise in the host
    [
      "raise 'boom'",
      "def bad(",
      "exit 1",
      "abort 'test'",
    ].each do |code|
      assert_instance_of Wasval::Result, Wasval.execute(code),
        "Wasval.execute should not raise for: #{code.inspect}"
    end
  end

  def test_execute_infinite_loop_times_out
    result = Wasval.execute("loop {}", timeout: 1)

    assert result.timeout?
    assert_equal :timeout, result.error_type
  end

  def test_execute_default_timeout_enforced
    # Default is 10s; use a per-call 1s override to test the mechanism
    result = Wasval.execute("loop {}", timeout: 1)
    assert result.timeout?
  end

  # US4: Memory limits
  def test_execute_memory_limit_enforced
    code = "a = []; loop { a << ('x' * 1_000_000) }"
    result = Wasval.execute(code, memory_limit: 32)
    assert_equal :memory_limit, result.error_type
  end

  def test_execute_memory_limit_per_call_override
    code = "a = []; loop { a << ('x' * 1_000_000) }"
    result = Wasval.execute(code, memory_limit: 16)
    assert_equal :memory_limit, result.error_type
  end

  # Polish: edge cases
  def test_execute_nil_code_returns_sandbox_error
    result = Wasval.execute(nil)
    refute result.success?
    assert_equal :sandbox_error, result.error_type
    refute_nil result.error_message
  end

  def test_execute_empty_code_returns_sandbox_error
    result = Wasval.execute("")
    refute result.success?
    assert_equal :sandbox_error, result.error_type
  end

  # Config
  def test_configure_sets_global_defaults
    original_timeout = Wasval.config.timeout
    original_memory = Wasval.config.memory_limit

    Wasval.configure do |c|
      c.timeout = 5
      c.memory_limit = 64
    end

    assert_equal 5, Wasval.config.timeout
    assert_equal 64, Wasval.config.memory_limit
  ensure
    Wasval.configure do |c|
      c.timeout = original_timeout
      c.memory_limit = original_memory
    end
  end

  def test_per_call_timeout_overrides_global
    Wasval.configure { |c| c.timeout = 30 }
    result = Wasval.execute("loop {}", timeout: 1)
    assert result.timeout?
  ensure
    Wasval.configure { |c| c.timeout = 10 }
  end
end
