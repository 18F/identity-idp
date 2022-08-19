require 'simplecov/no_defaults'
require 'simplecov-html'
require 'simplecov_json_formatter'
require 'simplecov-cobertura'

class SimplecovHelper
  def self.start
    configure
    SimpleCov.start

    at_exit do
      SimpleCov.run_exit_tasks!
    end
  end

  def self.configure
    SimpleCov.configure do
      if ENV['CI_JOB_NAME']
        # this puts results in different sub-folders of coverage/ for each parallel test worker
        #  by using the job name. Folders end up being coverage/specs-1-5, coverage/specs-2-5, etc.
        #  This is not necessarily folder name friendly, so non-alphabetic/numeric characters are
        #  removed.
        job_name = ENV['CI_JOB_NAME'].downcase.
          gsub(/[^a-z0-9]/, '-')[0..62].
          gsub(/(\A-+|-+\z)/, '')
        command_name job_name
        coverage_dir "coverage/#{job_name}"
      end

      enable_coverage :branch

      formatter SimpleCov::Formatter::MultiFormatter.new(configured_formatters)

      track_files '{app,lib}/**/*.rb'
      add_group 'Controllers', 'app/controllers'
      add_group 'Forms', 'app/forms'
      add_group 'Models', 'app/models'
      add_group 'Mailers', 'app/mailers'
      add_group 'Helpers', 'app/helpers'
      add_group 'Jobs', %w[app/jobs app/workers]
      add_group 'Libraries', 'lib/'
      add_group 'Presenters', 'app/presenters'
      add_group 'Services', 'app/services'
      add_filter %r{^/spec/}
      add_filter '/vendor/bundle/'
      add_filter '/config/'
      add_filter '/lib/deploy/migration_statement_timeout.rb'
      add_filter '/lib/tasks/create_test_accounts.rb'
      add_filter %r{^/db/}
      add_filter %r{^/\.gem/}
      add_filter %r{/vendor/ruby/}
    end
  end

  def self.configured_formatters
    formatters = [
      SimpleCov::Formatter::SimpleFormatter,
      SimpleCov::Formatter::HTMLFormatter,
    ]
    if ENV['GITLAB_CI']
      # GitLab CI uses Cobertura formatter to display diffs in pull requests
      formatters << SimpleCov::Formatter::CoberturaFormatter
    end

    formatters
  end
end
