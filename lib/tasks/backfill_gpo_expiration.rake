# rubocop:disable Metrics/BlockLength
namespace :profiles do
  desc 'Backfill the gpo_verification_expired_at value'

  ##
  # Usage:
  #
  # Print pending updates
  # bundle exec rake profiles:backfill_gpo_expiration > profiles.csv
  #
  # Commit updates
  # bundle exec rake profiles:backfill_gpo_expiration UPDATE_PROFILES=true > profiles.csv
  #
  task backfill_gpo_expiration: :environment do |_task, _args|
    min_profile_age = (ENV['MIN_PROFILE_AGE_IN_DAYS'].to_i || 100).days
    update_profiles = ENV['UPDATE_PROFILES'] == 'true'

    job = GpoExpirationJob.new

    profiles = job.gpo_profiles_that_should_be_expired(
      as_of: Time.zone.now,
      min_profile_age: min_profile_age,
    )

    profiles.find_each do |profile|
      gpo_verification_pending_at = profile.gpo_verification_pending_at

      if gpo_verification_pending_at.blank?
        raise "Profile #{profile.id} does not have gpo_verification_pending_at"
      end

      puts "#{profile.id},#{gpo_verification_pending_at.iso8601}"

      if update_profiles
        job.expire_profile(profile: profile)
      end
    end
  end

  ##
  # Usage:
  #
  # Rollback the above:
  #
  # bundle exec rake profiles:rollback_backfill_gpo_expiration < profiles.csv
  #
  task rollback_backfill_gpo_expiration: :environment do |_task, _args|
    profile_data = STDIN.read.split("\n").map do |profile_row|
      profile_row.split(',')
    end

    warn "Updating #{profile_data.count} records"

    profile_data.each do |profile_datum|
      profile_id, gpo_verification_pending_at = profile_datum
      Profile.where(id: profile_id).update!(
        gpo_verification_pending_at: Time.parse(gpo_verification_pending_at),
        gpo_verification_expired_at: nil,
      )
      warn profile_id
    end
  end
end
# rubocop:enable Metrics/BlockLength
