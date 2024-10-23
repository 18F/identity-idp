#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'optparse'
require 'pathname'

def get_new_primary_migration_files(base_branch)
  output, status = Open3.capture2(
    'git', 'diff', '--name-only', base_branch, 'db/primary_migrate/'
  )

  raise "error getting new primary migration files: #{output}" unless status.success?

  output.strip.split("\n")
end

def get_new_worker_jobs_migration_files(base_branch)
  output, status = Open3.capture2(
    'git', 'diff', '--name-only', base_branch, 'db/worker_jobs_migrate/'
  )

  raise "error getting new primary migration files: #{output}" unless status.success?

  output.strip.split("\n")
end

def get_migration_version_from_file_name(file_name)
  /^(?<version>\d+)_/.match(file_name).named_captures.fetch('version')
end

def parsed_options(args)
  options = { base_branch: 'main' }
  basename = File.basename($0)

  optparse = OptionParser.new do |opts|
    opts.banner = <<-EOM
      usage: #{basename} [OPTIONS]

    EOM
    opts.on('-h', '--help', 'Display this message') do
      warn opts
      exit
    end

    opts.on('-b', '--base_branch BASE_BRANCH', 'Name of base branch, defaults to main') do |val|
      options[:base_branch] = val
    end
  end

  optparse.parse!(args)
  options
end

def main(args)
  options = parsed_options(args)

  primary_migration_files = get_new_primary_migration_files(options[:base_branch])
  worker_jobs_migration_files = get_new_worker_jobs_migration_files(options[:base_branch])

  primary_migration_files.each do |file|
    file = Pathname.new(file)
    next unless file.exist?
    version = get_migration_version_from_file_name(file.basename.to_s)
    output, status = Open3.capture2(
      'bundle', 'exec', 'rake', 'db:migrate:down:primary', "VERSION=#{version}"
    )
    puts output
    raise 'failed to migrate primary database down' unless status.success?
  end

  worker_jobs_migration_files.map do |file|
    file = Pathname.new(file)
    next unless file.exist?
    version = get_migration_version_from_file_name(file.basename.to_s)
    next unless file.exist?
    output, status = Open3.capture2(
      'bundle', 'exec', 'rake', 'db:migrate:down:worker_jobs', "VERSION=#{version}"
    )
    puts output
    raise 'failed to migrate worker_jobs database down' unless status.success?
  end

  exit 0
end

main(ARGV) if File.expand_path(__FILE__) == File.expand_path($0)
