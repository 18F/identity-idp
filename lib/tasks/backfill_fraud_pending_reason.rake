namespace :profiles do
  desc 'If a profile is in review or rejected, store the reason it was marked for fraud'

  ##
  # Usage:
  #
  # Print pending updates
  # bundle exec rake profiles:backfill_fraud_pending_reason
  #
  # Commit updates
  # bundle exec rake profiles:backfill_fraud_pending_reason UPDATE_PROFILES=true
  #
  task backfill_fraud_pending_reason: :environment do |_task, _args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 60000')

    update_profiles = ENV['UPDATE_PROFILES'] == 'true'

    profiles = Profile.where(
      fraud_pending_reason: nil,
    ).where(
      'fraud_review_pending_at IS NOT NULL OR fraud_rejection_at IS NOT NULL',
    )

    profiles.each do |profile|
      proofing_component_status = profile.proofing_components&.[]('threatmetrix_review_status')
      fraud_pending_reason = case proofing_component_status
                             when 'review'
                               'threatmetrix_review'
                             when 'reject'
                               'threatmetrix_reject'
                             else
                               'threatmetrix_review'
                             end

      warn "#{profile.id},#{fraud_pending_reason},#{proofing_component_status}"
      profile.update!(fraud_pending_reason: fraud_pending_reason) if update_profiles
    end
  end

  ##
  # Usage:
  #
  # Rollback the above:
  #
  # export BACKFILL_OUTPUT='<backfill_output>'
  # bundle exec rake profiles:rollback_backfill_fraud_pending_reason
  #
  task rollback_backfill_fraud_pending_reason: :environment do |_task, _args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 60000')

    profile_ids = ENV['BACKFILL_OUTPUT'].split("\n").map do |profile_row|
      profile_row.split(',').first
    end

    warn "Updating #{profile_ids.count} records"
    Profile.where(id: profile_ids).update!(fraud_pending_reason: nil)
  end

  ##
  # Usage:
  # bundle exec rake profiles:validate_backfill_fraud_pending_reason
  #
  task validate_backfill_fraud_pending_reason: :environment do |_task, _args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 60000')

    profiles = Profile.where(
      fraud_pending_reason: nil,
    ).where(
      'fraud_review_pending_at IS NOT NULL OR fraud_rejection_at IS NOT NULL',
    )

    if profiles.empty?
      warn 'fraud_pending_reason backfill was successful'
    else
      warn "fraud_pending_reason backfill left #{profile.count} rows"
    end
  end
end
