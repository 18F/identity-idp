namespace :adhoc do
  desc 'Copy remember_device_revoked_at to user phone_confirmed_at on phone configurations'
  task migrate_remember_me_revoked_at: :environment do
    Rails.logger = Logger.new(STDOUT)
    RememberDeviceRevokedAtMigrator.new.call
  end
end
