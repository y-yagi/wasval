# Wasval

Wasval is a Ruby sandbox that executes Ruby code safely inside a WebAssembly runtime (via [wasmtime](https://github.com/bytecodealliance/wasmtime-rb)).

## Installation

```bash
bundle add wasval
```

Or install directly:

```bash
gem install wasval
```

## Setup

Wasval requires a `ruby.wasm` binary. Install it with the built-in installer:

```ruby
require "wasval"

Wasval::Install::RubyWasm.new.install
```

The binary is downloaded from the [ruby.wasm releases](https://github.com/ruby/ruby.wasm/releases) and saved to `~/.wasval/ruby.wasm` by default.

You can customize the destination via the `WASVAL_RUBY_WASM_PATH` environment variable or the `dest:` option:

```ruby
Wasval::Install::RubyWasm.new(dest: "/path/to/ruby.wasm").install
```

## Usage

Set the `WASVAL_RUBY_WASM_PATH` environment variable to point to the `ruby.wasm` binary, then execute Ruby code:

```ruby
result = Wasval.execute("puts 'hello'")

result.status        # => :success
result.output        # => "hello\n"
result.success?      # => true
```

### Configuration

```ruby
Wasval.configure do |config|
  config.timeout      = 10   # seconds (default: 5)
  config.memory_limit = 256  # MB (default: 128)
end
```

You can also pass per-call overrides:

```ruby
result = Wasval.execute(code, timeout: 3, memory_limit: 32)
```

### Result

`Wasval.execute` returns a `Wasval::Result` with the following attributes:

| Attribute | Description |
|---|---|
| `status` | `:success`, `:syntax_error`, `:runtime_error`, `:timeout`, `:memory_limit`, `:sandbox_error` |
| `output` | Captured stdout |
| `stderr` | Captured stderr |
| `error_message` | Human-readable error description (nil on success) |

Helper methods: `success?`, `timeout?`, `error_type`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, install the ruby.wasm binary:

```bash
bundle exec ruby -e "require 'wasval'; Wasval::Install::RubyWasm.new.install"
```

Set `WASVAL_RUBY_WASM_PATH` and run the tests:

```bash
export WASVAL_RUBY_WASM_PATH=~/.wasval/ruby.wasm
bundle exec rake test
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/y-yagi/wasval.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
