require 'io/console'

namespace :users do
  namespace :review do
    desc 'Pass a user that has a pending review'
    task pass: :environment do |_task, args|
      user_uuid = STDIN.getpass('Enter the User UUID to pass (input will be hidden):')
      user = User.find_by(uuid: user_uuid)

      if user.decorate.threatmetrix_review_pending? && user.proofing_component.review_eligible?
        result = ProofingComponent.find_by(user: user)
        result.update(threatmetrix_review_status: 'pass')
        puts "User's review state has been updated to #{result.threatmetrix_review_status}."
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

      if user.decorate.threatmetrix_review_pending? && user.proofing_component.review_eligible?
        result = ProofingComponent.find_by(user: user)
        result.update(threatmetrix_review_status: 'reject')
        puts "User's review state has been updated to #{result.threatmetrix_review_status}."
      elsif !user.proofing_component.review_eligible?
        puts 'User is past the 30 day review eligibility'
      else
        puts 'User was not found pending a review'
      end
    end
  end
end
