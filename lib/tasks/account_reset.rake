namespace :account_reset do
  desc 'Send Notifications'
  task send_notifications: :environment do
    AccountReset::GrantRequestsAndSendEmails.new.call
  end
end
