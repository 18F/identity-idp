namespace :disaster_mitigation do
  desc 'Deactivate or reactivate in-person proofing profiles'
  task :deactivate_in_person_profiles,
       [:dry_run, :status_type, :issuer] => :environment do |_task, args|
    dry_run = args[:dry_run]
    status_type = args[:status_type]
    issuer = args[:issuer]

    # todo: validate arguments

    puts 'Deactivating some profiles!'
    # todo: generate reversal steps
    reversal_info = 'tktk'
    puts "Steps to reverse this process: #{reversal_info}"

    # todo: call the appropriate service method based on status_type
    stats = DisasterMitigation::DeactivateInPersonProfiles.deactivate_pending_profiles(
      issuer, dry_run
    )

    puts "Steps to reverse this process: #{reversal_info}"
    # todo: log some stats: count of target records found, count of records updated, duration of task
  end
end
