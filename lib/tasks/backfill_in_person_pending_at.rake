namespace :profiles do
  desc 'Backfill the in_person_verification_pending_at value column.'

  ##
  # Usage:
  #
  # Print pending updates
  # bundle exec rake profiles:backfill_in_person_verification_pending_at
  #
  # Commit updates
  # bundle exec rake profiles:backfill_in_person_verification_pending_at UPDATE_PROFILES=true
  #
  task backfill_in_person_verification_pending_at: :environment do |_task, _args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 60000')

    update_profiles = ENV['UPDATE_PROFILES'] == 'true'

    profiles = Profile.where(
      deactivation_reason: 'in_person_verification_pending',
      in_person_verification_pending_at: nil,
    )

    profiles.each do |profile|
      timestamp = profile.updated_at || profile.created_at

      warn "#{profile.id},#{profile.deactivation_reason},#{timestamp}"
      if update_profiles
        profile.update!(
          in_person_verification_pending_at: timestamp,
          deactivation_reason: nil,
        )
      end
    end
  end

  ##
  # Usage:
  #
  # Rollback the above:
  #
  # export BACKFILL_OUTPUT='<backfill_output>'
  # bundle exec rake profiles:rollback_backfill_in_person_verification_pending_at
  #
  task rollback_backfill_in_person_verification_pending_at: :environment do |_task, _args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 60000')

    profile_data = ENV['BACKFILL_OUTPUT'].split("\n").map do |profile_row|
      profile_row.split(',')
    end

    warn "Updating #{profile_data.count} records"
    profile_data.each do |profile_datum|
      profile_id, deactivation_reason, _timestamp = profile_datum
      Profile.where(id: profile_id).update!(
        in_person_verification_pending_at: nil,
        deactivation_reason:,
      )
      warn profile_id
    end
  end

  ##
  # Usage:
  # bundle exec rake profiles:validate_backfill_in_person_verification_pending_at
  #
  task validate_backfill_in_person_verification_pending_at: :environment do |_task, _args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 60000')

    profiles = Profile.where(
      deactivation_reason: 'in_person_verification_pending',
      in_person_verification_pending_at: nil,
    )

    warn "backfill_in_person_verification_pending_at left #{profiles.count} rows"
  end
end
