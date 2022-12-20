namespace :users do
  desc 'Review a user profile and pass them'
  task review_user: :environment do |_task, args|
    require 'io/console'
    user_uuid = STDIN.getpass('Enter the UUID of the user to look up(input will be hidden): ')
    user = User.find_by(uuid: user_uuid)

    if user.present?
      review_status = ProofingComponent.find_by(user: user)
      puts('Do you want to pass or reject this user? [PASS/REJECT]:')
      pass_or_reject = STDIN.gets.strip.downcase
      if pass_or_reject == 'pass'
        review_status.update(threatmetrix_review_status: 'pass')
        puts "User's review state is updated to #{review_status.threatmetrix_review_status}"
      elsif pass_or_reject == 'reject'
        review_status.update(threatmetrix_review_status: 'reject')
        puts "User's review state is updated to #{review_status.threatmetrix_review_status}"
      else
        puts "User's review status has not changed"
      end
    else
      puts 'No user found'
    end
  end
end
