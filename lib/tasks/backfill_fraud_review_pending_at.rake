namespace :profiles do
  desc 'If a profile is in GPO and fraud pending state, move it out of fraud pending state'

  ##
  # Usage:
  #
  # Print pending updates
  # bundle exec rake profiles:backfill_fraud_review_pending_at
  #
  # Commit updates
  # bundle exec rake profiles:backfill_fraud_review_pending_at UPDATE_PROFILES=true
  #
  task backfill_fraud_review_pending_at: :environment do |_task, _args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 60000')

    update_profiles = ENV['UPDATE_PROFILES'] == 'true'

    profiles = Profile.where(
      'fraud_review_pending_at IS NOT NULL OR fraud_rejection_at IS NOT NULL',
    ).where.not(
      gpo_verification_pending_at: nil,
    )

    profiles.each do |profile|
      if profile.fraud_pending_reason.blank?
        warn "Profile ##{profile.id} does not have a fraud pending reason!"
        break
      end

      warn "#{profile.id},#{profile.fraud_review_pending_at},#{profile.fraud_rejection_at}"
      profile.update!(fraud_review_pending_at: nil, fraud_rejection_at: nil) if update_profiles
    end
  end

  ##
  # Usage:
  #
  # Rollback the above:
  #
  # export BACKFILL_OUTPUT='<backfill_output>'
  # bundle exec rake profiles:rollback_backfill_fraud_review_pending_at
  #
  task rollback_backfill_fraud_review_pending_at: :environment do |_task, _args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 60000')

    profile_data = ENV['BACKFILL_OUTPUT'].split("\n").map do |profile_row|
      profile_row.split(',')
    end

    warn "Updating #{profile_data.count} records"
    profile_data.each do |profile_datum|
      profile_id, fraud_review_pending_at, fraud_rejection_at = profile_datum
      Profile.where(id: profile_id).update!(
        fraud_review_pending_at: fraud_review_pending_at,
        fraud_rejection_at: fraud_rejection_at,
      )
    end
  end

  ##
  # Usage:
  # bundle exec rake profiles:validate_backfill_fraud_review_pending_at
  #
  task validate_backfill_fraud_review_pending_at: :environment do |_task, _args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 60000')

    profiles = Profile.where(
      'fraud_review_pending_at IS NOT NULL OR fraud_rejection_at IS NOT NULL',
    ).where.not(
      gpo_verification_pending_at: nil,
    )

    warn "fraud_pending_reason backfill left #{profiles.count} rows"
  end
end
