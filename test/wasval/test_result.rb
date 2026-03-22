# frozen_string_literal: true

require "test_helper"

class TestWasvalResult < Minitest::Test
  def test_success_result
    r = result(status: :success, output: "hello\n", stderr: "", error_message: nil)
    assert r.success?
    refute r.timeout?
    assert_nil r.error_type
    assert_nil r.error_message
    assert_equal "hello\n", r.output
    assert_equal "", r.stderr
  end

  def test_timeout_result
    r = result(status: :timeout, output: "", stderr: "", error_message: "execution timed out")
    refute r.success?
    assert r.timeout?
    assert_equal :timeout, r.error_type
    assert_equal "execution timed out", r.error_message
  end

  def test_syntax_error_result
    r = result(status: :syntax_error, output: "", stderr: "", error_message: "unexpected end")
    refute r.success?
    refute r.timeout?
    assert_equal :syntax_error, r.error_type
  end

  def test_runtime_error_result
    r = result(status: :runtime_error, output: "", stderr: "", error_message: "RuntimeError: boom")
    assert_equal :runtime_error, r.error_type
  end

  def test_memory_limit_result
    r = result(status: :memory_limit, output: "", stderr: "", error_message: "memory limit exceeded")
    assert_equal :memory_limit, r.error_type
  end

  def test_sandbox_error_result
    r = result(status: :sandbox_error, output: "", stderr: "", error_message: "nil input")
    assert_equal :sandbox_error, r.error_type
  end

  def test_output_always_string
    r = result(status: :success, output: nil, stderr: nil, error_message: nil)
    assert_instance_of String, r.output
    assert_instance_of String, r.stderr
  end

  def test_frozen
    r = result(status: :success, output: "", stderr: "", error_message: nil)
    assert r.frozen?
    assert_raises(FrozenError) { r.instance_variable_set(:@output, "x") }
  end

  def test_invalid_status_raises
    assert_raises(ArgumentError) do
      result(status: :unknown_status, output: "", stderr: "", error_message: nil)
    end
  end

  private

  def result(**kwargs)
    Wasval::Result.new(**kwargs)
  end
end
