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

    count = 0
    earliest = nil
    latest = nil

    on_profile_expired = ->(profile:, gpo_verification_pending_at:) do
      count += 1

      earliest = [earliest, gpo_verification_pending_at].compact.min
      latest = [latest, gpo_verification_pending_at].compact.max

      puts "#{profile.id},#{gpo_verification_pending_at.iso8601}"

      if count % 100 == 0
        verb = update_profiles ? 'Expired' : 'Found'
        warn "#{verb} #{count} profiles (earliest: #{earliest}, latest: #{latest})"
      end
    end

    job = GpoExpirationJob.new(on_profile_expired: on_profile_expired)

    job.perform(
      now: Time.zone.now,
      min_profile_age: min_profile_age,
      dry_run: !update_profiles,
    )
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
        gpo_verification_pending_at: Time.zone.parse(gpo_verification_pending_at),
        gpo_verification_expired_at: nil,
      )
      warn profile_id
    end
  end
end
