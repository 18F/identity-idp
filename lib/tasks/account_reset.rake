# frozen_string_literal: true

namespace :account_reset do
  desc 'Send Notifications'
  task send_notifications: :environment do
    GrantAccountResetRequestsAndSendEmails.new.call
  end
end
