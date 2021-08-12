#!/usr/bin/env ruby

require_relative '../spec/simplecov_helper'

module SimpleCov
  module ResultMerger
    def self.merging!
      SimplecovHelper.configure
      fix_paths
      SimpleCov.collate Dir['coverage/**/.resultset.json'] do
        merge_timeout 365 * 24 * 3600
      end
    end

    def self.fix_paths
      Dir['coverage/**/.resultset.json'].each do |file|
        content = File.read(file)
        json = JSON.parse(content)
        first_key = json.keys.first
        second_key = json[first_key].keys.first
        path = json.dig(first_key, second_key).keys.first
        paths = path.split('identity-idp')
        first_path = paths.first
        new_path = Dir.pwd.split('identity-idp').first
        content.gsub!(first_path, new_path)
        File.write(file, content)
      end
    end
  end
end

SimpleCov::ResultMerger.merging!
