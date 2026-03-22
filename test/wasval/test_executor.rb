# frozen_string_literal: true

require "test_helper"

class TestWasvalExecutor < Minitest::Test
  def test_syntax_error_returns_correct_type
    result = Wasval.execute("def broken(")
    refute result.success?
    assert_equal :syntax_error, result.error_type
    refute_nil result.error_message
  end

  def test_runtime_error_returns_correct_type
    result = Wasval.execute("raise 'boom'")
    refute result.success?
    assert_equal :runtime_error, result.error_type
    refute_nil result.error_message
  end

  def test_undefined_constant_returns_runtime_error
    result = Wasval.execute("UnknownClass.new")
    refute result.success?
    assert_equal :runtime_error, result.error_type
    refute_nil result.error_message
  end

  def test_no_exception_raised_in_host_for_syntax_error
    assert_instance_of Wasval::Result, Wasval.execute("def bad(")
  end

  def test_no_exception_raised_in_host_for_runtime_error
    assert_instance_of Wasval::Result, Wasval.execute("raise 'boom'")
  end

  def test_no_exception_raised_in_host_for_undefined_constant
    assert_instance_of Wasval::Result, Wasval.execute("UnknownClass.new")
  end

  def test_infinite_loop_returns_timeout
    result = Wasval.execute("loop {}", timeout: 2)
    assert result.timeout?
    assert_equal :timeout, result.error_type
  end

  def test_timeout_completes_within_deadline
    start = Time.now
    Wasval.execute("loop {}", timeout: 1)
    assert Time.now - start < 3
  end

  def test_memory_limit_enforced
    result = Wasval.execute("a = []; loop { a << ('x' * 1_000_000) }", memory_limit: 32)
    assert_equal :memory_limit, result.error_type
  end

  def test_config_default_timeout
    assert_equal 5, Wasval::Config::DEFAULT_TIMEOUT
  end

  def test_config_default_memory_limit
    assert_equal 128, Wasval::Config::DEFAULT_MEMORY_LIMIT
  end

  def test_config_attribute_setters
    config = Wasval::Config.new
    config.timeout = 2
    config.memory_limit = 32
    assert_equal 2, config.timeout
    assert_equal 32, config.memory_limit
  end

  def test_per_call_timeout_overrides_global_config
    Wasval.configure { |c| c.timeout = 30 }
    result = Wasval.execute("loop {}", timeout: 1)
    assert result.timeout?
  ensure
    Wasval.configure { |c| c.timeout = 10 }
  end

  def test_per_call_memory_overrides_global_config
    Wasval.configure { |c| c.memory_limit = 256 }
    result = Wasval.execute("a = []; loop { a << ('x' * 1_000_000) }", memory_limit: 16)
    assert_equal :memory_limit, result.error_type
  ensure
    Wasval.configure { |c| c.memory_limit = 128 }
  end
end
