# frozen_string_literal: true

namespace :run_once_data_migration do
  desc 'Reset sign_in_new_device_at between start_date and end_date in batches of batch_size'
  task :reset_sign_in_new_device_at,
       [:start_date, :end_date, :batch_size] => [:environment] do |_task, args|
    LAST_VALID_END_DATE = '2026-02-04'

    if args.count != 3
      warn 'All arguments must be specified'
      exit(-1)
    end

    if args.end_date > LAST_VALID_END_DATE
      warn "end_date must be <= #{LAST_VALID_END_DATE}"
      exit(-1)
    end

    puts "Batch size: #{args.batch_size}, Start: #{args.start_date}, End: #{args.end_date}"

    total = 0
    loop do
      # rubocop:disable Rails::SkipsModelValidations
      update_count = User
        .where('sign_in_new_device_at BETWEEN :start_date AND :end_date',
               { start_date: args.start_date, end_date: args.end_date })
        .limit(args.batch_size)
        .update_all(sign_in_new_device_at: nil)
      # rubocop:enable Rails::SkipsModelValidations
      total += update_count
      if update_count == 0
        break
      else
        print '.'
      end
    end
    puts "\n#{total} total rows updated"
  end
end
