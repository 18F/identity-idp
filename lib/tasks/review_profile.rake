require 'io/console'

namespace :users do
  namespace :review do
    desc 'Pass a user that has a pending review'
    task pass: :environment do |_task, args|
      user_uuid = STDIN.getpass('Enter the User UUID to pass (input will be hidden):')
      user = User.find_by(uuid: user_uuid)

      if user.fraud_review_pending? && user.proofing_component.review_eligible?
        profile = user.fraud_review_pending_profile
        profile.activate_after_passing_review

        if profile.active?
          event, disavowal_token = UserEventCreator.new(current_user: user).
            create_out_of_band_user_event_with_disavowal(:account_verified)

          UserAlerts::AlertUserAboutAccountVerified.call(
            user: user,
            date_time: event.created_at,
            sp_name: nil,
            disavowal_token: disavowal_token,
          )

          puts "User's profile has been activated and the user has been emailed."
        else
          puts "There was an error activating the user's profile please try again"
        end
      elsif !user.proofing_component.review_eligible?
        puts 'User is past the 30 day review eligibility'
      else
        puts 'User was not found pending a review'
      end
    end

    desc 'Reject a user that has a pending review'
    task reject: :environment do |_task, args|
      user_uuid = STDIN.getpass('Enter the User UUID to reject (input will be hidden):')
      user = User.find_by(uuid: user_uuid)

      if user.fraud_review_pending? && user.proofing_component.review_eligible?
        profile = user.fraud_review_pending_profile

        profile.reject_for_fraud(notify_user: true)

        puts "User's profile has been deactivated due to fraud rejection."
      elsif !user.proofing_component.review_eligible?
        puts 'User is past the 30 day review eligibility'
      else
        puts 'User was not found pending a review'
      end
    end
  end
end
