# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "wasval"
require "debug"
Wasval.execute("") # NOTE: This is for load runtime.

require "minitest/autorun"
