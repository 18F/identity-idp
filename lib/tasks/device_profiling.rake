namespace :device_profiling do
  desc 'Approve rejected device profiling results to pass for list of UUIDs'
  task :approve_rejected_users, [:user_uuids] => :environment do |_task, args|
    user_uuids = args[:user_uuids]
    profiling_type = 'account_creation'

    if user_uuids.blank?
      puts "Error: user_uuids is required"
      exit 1
    end

    # Parse UUIDs
    uuid_list = user_uuids.split(',').map(&:strip).reject(&:blank?)
    
    puts "Processing #{uuid_list.count} user UUID(s)"
    puts "Action: Change 'reject' to 'pass' (skip if already 'pass')"
    puts ""

    total_users_processed = 0
    total_results_updated = 0
    skipped_already_passed = 0
    users_with_no_results = 0

    uuid_list.each do |user_uuid|
      total_users_processed += 1
      
      begin
        # Find user by UUID
        user = User.find_by(uuid: user_uuid)
        if user.blank?
          puts " User not found: #{user_uuid}"
          next
        end

        # Find device profiling results for this user (reject or pass)
        result = DeviceProfilingResult.where(
          user_id: user.id,
          type: DeviceProfilingResult::PROFILING_TYPES[:account_creation]
        ).first

        if result.nil?
          users_with_no_results += 1
          puts "No device profiling results found for: #{user_uuid} (#{user.email})"
          next
        end

        # Check if already passed

        if result.review_status == 'pass'
          skipped_already_passed += 1
          puts "Already passed: #{user_uuid}"
          next
        end

        # Update rejected results to pass
        puts "Updating rejected result for: #{user_uuid}"
        puts "  - DeviceProfilingResult ID: #{result.id} (#{result.created_at.strftime('%Y-%m-%d %H:%M')})"
        result.update!(review_status: 'pass')
        total_results_updated += 1

        puts "Successfully updated result for: #{user_uuid}"
        
        # Log for audit

      rescue => e
        puts "Error processing #{user_uuid}: #{e.message}"
      end
    end

    puts ""
    puts "=" * 80
    puts "SUMMARY:"
    puts "Total users processed: #{total_users_processed}"
    puts "Results updated (reject → pass): #{total_results_updated}"
    puts "Users already passed: #{skipped_already_passed}"
    puts "Users with no results: #{users_with_no_results}"

    puts "Task completed successfully!"
  end
end