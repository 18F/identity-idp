namespace :adhoc do
  USAGE_WARNING =
    '
      WARNING: Running this task without EMAILS argument is a noop
      Usage: rake adhoc:reset_passwords_and_notify_users EMAILS=user1@asdf.com,user2@asdf.com
    '.freeze

  desc 'Reset the passwords for a comma separated list of users'
  task reset_passwords_and_notify_users: :environment do
    emails_input = ENV['EMAILS']
    next warn(USAGE_WARNING) if emails_input.blank?

    emails = emails_input.split(',')
    emails.each do |email|
      ResetPasswordAndNotifyUser.new(email).call
    end
  end
end
