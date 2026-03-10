# frozen_string_literal: true

namespace :manual_phone_review do
  desc 'Add a user to the manually reviewed phone set'
  task :add_user, [:email] => :environment do |_t, args|
    # Implementation for adding user to manually reviewed phone set
    email = args[:email]
    if email.blank?
      puts 'Email argument is required.'
      next
    end

    user = User.find_with_email(args[:email].downcase)
    unless user
      puts 'No user found with that email'
      next
    end

    user_uuid = user.uuid
    manually_reviewed_phone_user_set = Idv::ManuallyReviewedPhoneUserSet.new
    manually_reviewed_phone_user_set.add_user!(user_uuid: user_uuid)
    puts "User #{user_uuid} added to the manually reviewed phone set."
  end

  desc 'Remove a user from the manually reviewed phone set'
  task :remove_user, [:email] => :environment do |_t, args|
    # Implementation for removing user from manually reviewed phone set
    email = args[:email]
    if email.blank?
      puts 'Email argument is required.'
      next
    end

    user = User.find_with_email(args[:email].downcase)
    unless user
      puts 'No user found with that email'
      next
    end

    user_uuid = user.uuid
    manually_reviewed_phone_user_set = Idv::ManuallyReviewedPhoneUserSet.new
    manually_reviewed_phone_user_set.remove_user!(user_uuid: user_uuid)
    puts "User #{user_uuid} removed from the manually reviewed phone set."
  end

  desc 'Total count of users in the manually reviewed phone set'
  task users_count: :environment do
    # Implementation for listing all users in the manually reviewed phone set
    manually_reviewed_phone_user_set = Idv::ManuallyReviewedPhoneUserSet.new
    count = manually_reviewed_phone_user_set.count
    puts "There are currently #{count} users in the manually reviewed phone set."
  end

  desc 'Remove expired users from the manually reviewed phone set'
  task remove_expired_users: :environment do
    # Implementation for removing expired users from the manually reviewed phone set
    manually_reviewed_phone_user_set = Idv::ManuallyReviewedPhoneUserSet.new
    manually_reviewed_phone_user_set.remove_expired_members!
    puts 'Expired users removed from the manually reviewed phone set.'
  end

  desc 'Check if a user is active in the manually reviewed phone set'
  task :check_user_active, [:email] => :environment do |_t, args|
    # Implementation for checking if a user is in the manually reviewed phone set
    email = args[:email]
    if email.blank?
      puts 'Email argument is required.'
      next
    end

    user = User.find_with_email(args[:email].downcase)
    unless user
      puts 'No user found with that email'
      next
    end

    user_uuid = user.uuid
    manually_reviewed_phone_user_set = Idv::ManuallyReviewedPhoneUserSet.new
    if manually_reviewed_phone_user_set.active_member?(user_uuid: user_uuid)
      puts "User #{user_uuid} is in the manually reviewed phone set."
    else
      puts "User #{user_uuid} is NOT in the manually reviewed phone set."
    end
  end

  desc 'Check if a user is in the manually reviewed phone set'
  task :check_user, [:email] => :environment do |_t, args|
    # Implementation for checking if a user is in the manually reviewed phone set
    email = args[:email]
    if email.blank?
      puts 'Email argument is required.'
      next
    end

    user = User.find_with_email(args[:email].downcase)
    unless user
      puts 'No user found with that email'
      next
    end

    user_uuid = user.uuid
    manually_reviewed_phone_user_set = Idv::ManuallyReviewedPhoneUserSet.new
    if manually_reviewed_phone_user_set.fetch_member_score(user_uuid: user_uuid)
      puts "User #{user_uuid} is in the manually reviewed phone set."
    else
      puts "User #{user_uuid} is NOT in the manually reviewed phone set."
    end
  end
end
