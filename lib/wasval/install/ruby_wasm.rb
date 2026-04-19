# frozen_string_literal: true

require "net/http"
require "uri"
require "zlib"
require "rubygems/package"
require "fileutils"
require "tmpdir"
require "wasmtime"

module Wasval
  module Install
    class RubyWasm
      GITHUB_RELEASES_URL = "https://github.com/ruby/ruby.wasm/releases/latest/download"
      TARGET = "wasm32-unknown-wasip1"
      BINARY_PATH_IN_TAR = "usr/local/bin/ruby"
      DEFAULT_INSTALL_DIR = File.expand_path("~/.wasval")
      DEFAULT_BINARY_NAME = "ruby.wasm"
      DEFAULT_SERIALIZED_BINARY_NAME = "ruby.cwasm"
      DEFAULT_PACKED_BINARY_NAME = "ruby-packed.wasm"
      DEFAULT_USR_DIR_NAME = "usr"

      attr_reader :dest, :serialized_dest, :ruby_version, :profile, :pack_dirs, :pack_output, :include_gems

      def initialize(dest: nil, serialized_dest: nil, ruby_version: nil, profile: :full, pack_dirs: nil, pack_output: nil, include_gems: nil)
        @ruby_version = ruby_version || ENV["WASVAL_RUBY_VERSION"] || default_ruby_version
        @profile = profile.to_s
        @dest = dest || ENV["WASVAL_RUBY_WASM_PATH"] || File.join(DEFAULT_INSTALL_DIR, DEFAULT_BINARY_NAME)
        @serialized_dest = serialized_dest || ENV["WASVAL_RUBY_CWASM_PATH"] || File.join(File.dirname(@dest), DEFAULT_SERIALIZED_BINARY_NAME)
        @pack_dirs = pack_dirs
        @pack_output = pack_output || File.join(File.dirname(@dest), DEFAULT_PACKED_BINARY_NAME)
        @include_gems = include_gems
      end

      def download
        FileUtils.mkdir_p(File.dirname(dest))
        Dir.mktmpdir do |tmpdir|
          tarball_path = File.join(tmpdir, tarball_name)
          download_file(download_url, tarball_path)
          extract_binary(tarball_path)
        end
        dest
      end

      def install
        FileUtils.mkdir_p(File.dirname(dest))
        Dir.mktmpdir do |tmpdir|
          tarball_path = File.join(tmpdir, tarball_name)
          download_file(download_url, tarball_path)
          extract_binary(tarball_path)
          if pack_dirs || include_gems
            dirs = pack_dirs ? pack_dirs.dup : []
            if include_gems
              if include_gems == true
                actual_usr_dir = File.join(tmpdir, DEFAULT_USR_DIR_NAME)
                extract_usr_dir(tarball_path, actual_usr_dir)
              else
                actual_usr_dir = include_gems
              end
              dirs << actual_usr_dir
            end
            pack(*dirs, output: pack_output) if dirs.any?
          end
        end
        serialize
      end

      def serialize
        engine = Wasmtime::Engine.new(epoch_interruption: true)
        source = (pack_dirs || include_gems) ? pack_output : dest
        mod = Wasmtime::Module.from_file(engine, source)
        FileUtils.mkdir_p(File.dirname(serialized_dest))
        File.binwrite(serialized_dest, mod.serialize)
        serialized_dest
      end

      def pack(*dirs, output:)
        args = [dest]
        dirs.each do |dir|
          dir_arg = dir.include?("::") ? dir : "#{dir}::/#{File.basename(dir)}"
          args.push("--dir", dir_arg)
        end
        args.push("-o", output)

        system("rbwasm", "pack", *args, exception: true)
        output
      end

      def installed?
        File.exist?(dest)
      end

      def tarball_name
        "ruby-#{ruby_version}-#{TARGET}-#{profile}.tar.gz"
      end

      def download_url
        "#{GITHUB_RELEASES_URL}/#{tarball_name}"
      end

      private

      def default_ruby_version
        "3.4"
      end

      def download_file(url, dest_path, redirect_limit: 10)
        raise "Too many redirects for #{url}" if redirect_limit == 0

        uri = URI.parse(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(Net::HTTP::Get.new(uri)) do |response|
            case response
            when Net::HTTPSuccess
              File.open(dest_path, "wb") do |f|
                response.read_body { |chunk| f.write(chunk) }
              end
            when Net::HTTPRedirection
              download_file(response["location"], dest_path, redirect_limit: redirect_limit - 1)
            else
              raise "Failed to download #{url}: #{response.code} #{response.message}"
            end
          end
        end
      end

      def extract_usr_dir(tarball_path, dest_usr_dir)
        Dir.mktmpdir do |extract_dir|
          system("tar", "-xzf", tarball_path, "-C", extract_dir, exception: true)
          src_usr = Dir.glob("#{extract_dir}/**/usr").min_by(&:length)
          raise "usr directory not found in tarball" unless src_usr && File.directory?(src_usr)
          FileUtils.cp_r(src_usr, File.dirname(dest_usr_dir))
        end
        dest_usr_dir
      end

      def extract_binary(tarball_path)
        Zlib::GzipReader.open(tarball_path) do |gz|
          Gem::Package::TarReader.new(gz) do |tar|
            tar.each do |entry|
              next unless entry.file? && entry.full_name.end_with?(BINARY_PATH_IN_TAR)

              File.open(dest, "wb") { |f| f.write(entry.read) }
              File.chmod(0o755, dest)
              return
            end
          end
        end
        raise "Ruby binary not found in tarball (expected path: #{BINARY_PATH_IN_TAR})"
      end
    end
  end
end
