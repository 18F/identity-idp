#!/usr/bin/env ruby

require_relative '../spec/simplecov_helper'

module SimpleCov
  module ResultMerger
    RSPEC_FILENAME_REGEX = %r{^(?<filename>[-_\w\d/.]+(?<extension>\.rb)?)}
    def self.merging!
      SimplecovHelper.configure
      fix_gitlab_paths if ENV['GITLAB_CI']
      SimpleCov.collate Dir['coverage/**/.resultset.json'] do
        merge_timeout 365 * 24 * 3600
      end

      merge_json_reports
    end

    def self.merge_json_reports
      merged_hash = {
        'examples' => [],
        'summary' => {
          'example_count' => 0,
          'failure_count' => 0,
          'pending_count' => 0,
          'errors_outside_of_examples_count' => 0,
        },
        'seed' => nil,
        'version' => nil,
        'summary_line' => nil,
      }
      Dir['rspec_json/*.json'].each do |file|
        file_json = JSON.parse(File.read(file))
        merged_hash['summary']['example_count'] += file_json['summary']['example_count']
        merged_hash['summary']['failure_count'] += file_json['summary']['failure_count']
        merged_hash['summary']['pending_count'] += file_json['summary']['pending_count']
        merged_hash['summary']['errors_outside_of_examples_count'] +=
          file_json['summary']['errors_outside_of_examples_count']
        merged_hash['examples'] += file_json['examples']
      end

      File.write('rspec_json/rspec.json', merged_hash.to_json)

      knapsack = merged_hash['examples'].group_by do |x|
        RSPEC_FILENAME_REGEX.match(x['id'][2..])[:filename]
      end.map do |filename, examples|
        [filename, examples.map { |x| x['run_time'] }.sum]
      end.sort.to_h

      File.write('knapsack_rspec_report.json', JSON.pretty_generate(knapsack))
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
