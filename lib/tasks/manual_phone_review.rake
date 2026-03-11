# frozen_string_literal: true

namespace :manual_phone_review do
  desc 'Confirm manual phone review for a user'
  task add_user: :environment do
    # Implementation for adding user to manually reviewed phone set
    uuid = ENV['UUID']
    if uuid.blank?
      puts 'uuid argument is required'
      next
    end

    user = User.find_by(uuid:)
    unless user
      puts 'No user found with that uuid'
      next
    end

    user_uuid = user.uuid
    manually_reviewed_phone_user_set = Idv::ManuallyReviewedPhoneUserSet.new
    manually_reviewed_phone_user_set.add_user!(user_uuid: user_uuid)
    puts "User #{user_uuid} added to manually reviewed users"
  end

  desc 'Remove manual phone review for a user'
  task remove_user: :environment do
    # Implementation for removing user from manually reviewed phone set
    uuid = ENV['UUID']
    if uuid.blank?
      puts 'uuid argument is required'
      next
    end

    user = User.find_by(uuid:)
    unless user
      puts 'No user found with that uuid'
      next
    end

    user_uuid = user.uuid
    manually_reviewed_phone_user_set = Idv::ManuallyReviewedPhoneUserSet.new
    manually_reviewed_phone_user_set.remove_user!(user_uuid: user_uuid)
    puts "User #{user_uuid} removed from manually reviewed users"
  end

  desc 'Total count of manually phone reviewed users'
  task users_count: :environment do
    # Implementation for listing all users in the manually reviewed phone set
    manually_reviewed_phone_user_set = Idv::ManuallyReviewedPhoneUserSet.new
    count = manually_reviewed_phone_user_set.count
    puts "There are #{count} manually reviewed users"
  end

  desc 'Check user manual phone review status'
  task user_status: :environment do
    # Implementation for checking if a user is in the manually reviewed phone set
    uuid = ENV['UUID']
    if uuid.blank?
      puts 'uuid argument is required'
      next
    end

    user = User.find_by(uuid:)
    unless user
      puts 'No user found with that uuid'
      next
    end

    duration = IdentityConfig.store.idv_phone_confirmation_manual_review_validity_hours.hours.to_i
    user_uuid = user.uuid
    manually_reviewed_phone_user_set = Idv::ManuallyReviewedPhoneUserSet.new
    if (score = manually_reviewed_phone_user_set.fetch_member_score(user_uuid: user_uuid))
      expiration = score + duration
      puts "User #{user_uuid} found. Expiration: #{Time.zone.at(expiration)}"
    else
      puts "User #{user_uuid} was not manually reviewed"
    end
  end
end
