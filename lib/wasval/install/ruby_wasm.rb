# frozen_string_literal: true

require "net/http"
require "uri"
require "zlib"
require "rubygems/package"
require "fileutils"
require "tmpdir"

module Wasval
  module Install
    class RubyWasm
      GITHUB_RELEASES_URL = "https://github.com/ruby/ruby.wasm/releases/latest/download"
      TARGET = "wasm32-unknown-wasip1"
      BINARY_PATH_IN_TAR = "usr/local/bin/ruby"
      DEFAULT_INSTALL_DIR = File.expand_path("~/.wasval")
      DEFAULT_BINARY_NAME = "ruby.wasm"

      attr_reader :dest, :ruby_version, :profile

      def initialize(dest: nil, ruby_version: nil, profile: :full)
        @ruby_version = ruby_version || default_ruby_version
        @profile = profile.to_s
        @dest = dest || ENV["WASVAL_RUBY_WASM_PATH"] || File.join(DEFAULT_INSTALL_DIR, DEFAULT_BINARY_NAME)
      end

      def install
        FileUtils.mkdir_p(File.dirname(dest))
        Dir.mktmpdir do |tmpdir|
          tarball_path = File.join(tmpdir, tarball_name)
          download(download_url, tarball_path)
          extract_binary(tarball_path)
        end
        dest
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
        RUBY_VERSION.split(".").first(2).join(".")
      end

      def download(url, dest_path, redirect_limit: 10)
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
              download(response["location"], dest_path, redirect_limit: redirect_limit - 1)
            else
              raise "Failed to download #{url}: #{response.code} #{response.message}"
            end
          end
        end
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
