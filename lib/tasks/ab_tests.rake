# frozen_string_literal: true

namespace :ab_tests do
  desc 'Deletes persisted A/B test assignments for outdated tests'
  task :delete_outdated, [:confirm] => :environment do |_t, args|
    args.with_defaults(confirm: false)

    configured_experiments = AbTests.all.values.map(&:experiment)
    outdated_assignments = AbTestAssignment.where.not(experiment: configured_experiments)

    names = outdated_assignments.distinct.pluck(:experiment).sort
    if names.empty?
      warn 'No outdated test assignments to delete!'
      next
    end

    puts 'Found outdated test assignments with experiment names:'
    names.each { |name| puts "  - #{name}" }
    puts ''

    if args.confirm
      deleted = log_to_stdout { outdated_assignments.in_batches.delete_all }
      puts "\nSuccessfully deleted #{deleted} #{'record'.pluralize(deleted)}."
    else
      puts <<~STR
        Re-run command with `confirm` arg to delete:

          rake "ab_tests:delete_outdated[confirm]"

      STR
    end
  end
end

def log_to_stdout
  original_logger = ActiveRecord::Base.logger
  stdout_logger = Logger.new(STDOUT)
  ActiveRecord::Base.logger = ActiveSupport::BroadcastLogger.new(original_logger, stdout_logger)
  yield
ensure
  ActiveRecord::Base.logger = original_logger
end
