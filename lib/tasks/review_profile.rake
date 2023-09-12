require 'io/console'
# Note: This file should be going away soon!.
# Any modifications made here should be updated accordingly in the lib/action_account.rb file.
namespace :users do
  namespace :review do
    desc 'Pass a user that has a pending review'
    task pass: :environment do |_task, args|
      user = nil
      success = false
      exception = nil

      STDOUT.sync = true
      STDOUT.print 'Enter the name of the investigator: '
      investigator_name = STDIN.gets.chomp
      STDOUT.print 'Enter the issue/ticket/reason for the investigation: '
      investigation_number = STDIN.gets.chomp
      STDOUT.print 'Enter the User UUID to pass: '
      user_uuid = STDIN.gets.chomp
      STDOUT.puts "investigator name: #{investigator_name}"
      STDOUT.puts "investigation reason: #{investigation_number}"
      STDOUT.puts "uuid: #{user_uuid}"
      user = User.find_by(uuid: user_uuid)

      if !user
        error = 'Error: Could not find user with that UUID'
        next
      end

      if !user.fraud_review_pending?
        error = 'Error: User does not have a pending fraud review'
        next
      end

      if FraudReviewChecker.new(user).fraud_review_eligible?
        profile = user.fraud_review_pending_profile
        profile.activate_after_passing_review

        if profile.active?
          event, _disavowal_token = UserEventCreator.new(current_user: user).
            create_out_of_band_user_event(:account_verified)

          UserAlerts::AlertUserAboutAccountVerified.call(
            user: user,
            date_time: event.created_at,
            sp_name: nil,
          )

          success = true
          STDOUT.puts "User's profile has been activated and the user has been emailed."
        else
          error = "There was an error activating the user's profile. Please try again"
        end
      else
        error = 'User is past the 30 day review eligibility'
      end
    rescue StandardError => e
      success = false
      exception = e
      raise e
    ensure
      analytics_error_hash = nil
      if error.present?
        STDOUT.puts error
        analytics_error_hash = { message: error }
      end

      Analytics.new(
        user: user || AnonymousUser.new, request: nil, session: {}, sp: nil,
      ).fraud_review_passed(success:, errors: analytics_error_hash, exception: exception&.inspect)
    end

    desc 'Reject a user that has a pending review'
    task reject: :environment do |_task, args|
      error = nil
      user = nil
      success = false

      STDOUT.sync = true
      STDOUT.print 'Enter the name of the investigator: '
      investigator_name = STDIN.gets.chomp
      STDOUT.print 'Enter the issue/ticket/reason for the investigation: '
      investigation_number = STDIN.gets.chomp
      STDOUT.print 'Enter the User UUID to reject: '
      user_uuid = STDIN.gets.chomp
      STDOUT.puts "investigator name: #{investigator_name}"
      STDOUT.puts "investigation reason: #{investigation_number}"
      STDOUT.puts "uuid: #{user_uuid}"
      user = User.find_by(uuid: user_uuid)

      if !user
        error = 'Error: Could not find user with that UUID'
        next
      end

      if !user.fraud_review_pending?
        error = 'Error: User does not have a pending fraud review'
        next
      end

      if FraudReviewChecker.new(user).fraud_review_eligible?
        profile = user.fraud_review_pending_profile

        profile.reject_for_fraud(notify_user: true)

        success = true
        STDOUT.puts "User's profile has been deactivated due to fraud rejection."
      else
        error = 'User is past the 30 day review eligibility'
      end
    rescue StandardError => e
      success = false
      exception = e
      raise e
    ensure
      analytics_error_hash = nil
      if error.present?
        STDOUT.puts error
        analytics_error_hash = { message: error }
      end

      Analytics.new(
        user: user || AnonymousUser.new, request: nil, session: {}, sp: nil,
      ).fraud_review_rejected(success:, errors: analytics_error_hash, exception: exception&.inspect)
    end
  end
end
