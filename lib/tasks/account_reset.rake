namespace :account_reset do
  desc 'Send Notifications'
  task send_notifications: :environment do
    AccountResetService.grant_tokens_and_send_notifications
  end
end
