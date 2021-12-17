#!/usr/bin/env ruby

require_relative '../spec/simplecov_helper'

module SimpleCov
  module ResultMerger
    def self.merging!
      SimplecovHelper.configure
      fix_gitlab_paths if ENV['GITLAB_CI']
      SimpleCov.collate Dir['coverage/**/.resultset.json'] do
        merge_timeout 365 * 24 * 3600
      end
    end

    # simple_cov has SimpleCov.collate to merge coverage results, but it uses absolute paths.
    # If the paths are not identical, it report 0/0 lines of coverage. Since we run tests in
    # parallel hosts, and the absolute paths include a unique identifier. One build will run
    # under '/builds/Av8zM41c/9', and another will be '/builds/Z28zN92c/0', etc.
    #
    # The structure of the different .resultset.json files is:
    #
    #   {
    #     "specs-2-5": {
    #       "coverage": {
    #         "/builds/Av8zM41c/0/lg/identity-idp/lib/identity_config.rb": {
    #         ...
    #
    # This brittle function reads the third nested key to get each original absolute path, and
    # replaces it with the current host's absolute path with everything before 'identity-idp'.
    #
    def self.fix_gitlab_paths
      Dir['coverage/**/.resultset.json'].each do |file|
        content = File.read(file)
        json = JSON.parse(content)

        # ex: "specs-2-5"
        first_key = json.keys.first
        # ex: "coverage"
        second_key = json[first_key].keys.first
        # ex: "/builds/Av8zM41c/0/lg/identity-idp/lib/identity_config.rb"
        path = json.dig(first_key, second_key).keys.first
        paths = path.split('identity-idp')
        # ex: "/builds/Av8zM41c/0/lg/"
        first_path = paths.first
        new_path = Dir.pwd.split('identity-idp').first
        content.gsub!(first_path, new_path)
        File.write(file, content)
      end
    end
  end
end

SimpleCov::ResultMerger.merging! if $PROGRAM_NAME == __FILE__
