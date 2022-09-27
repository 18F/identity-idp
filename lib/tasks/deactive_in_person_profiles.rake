namespace :disaster_mitigation do
  desc 'Deactive or reactivate in-person proofing profiles'
  task :deactivate_in_person_profiles, [:arg1, :arg2] => :environment do |_task, args|
    puts 'mitigating disaster'
    # binding.pry
    arg1 = args[:arg1]
    arg2 = args[:arg2]

    # Load all profiles which are active and which were activated as part of in-person proofing
    DisasterMitigation::DeactivateInPersonProfiles.deactivate_profiles(arg1, arg2)
  end
end
