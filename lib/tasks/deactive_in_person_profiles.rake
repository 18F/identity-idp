namespace :disaster_mitigation do
  desc 'Deactive or reactivate in-person proofing profiles'
  task :deactivate_in_person_profiles,
       [:dry_run, :status_type, :partner_id] => :environment do |_task, args|
    dry_run = args[:dry_run]
    status_type = args[:status_type]
    partner_id = args[:partner_id]

    # Load all profiles which are active and which were activated as part of in-person proofing
    DisasterMitigation::DeactivateInPersonProfiles.deactivate_profiles(
      dry_run, status_type,
      partner_id
    )
  end
end
