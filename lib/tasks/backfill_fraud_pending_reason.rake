namespace :profiles do
  desc 'If a profile is in review or rejected, store the reason it was marked for fraud'

  task backfill_fraud_pending_reason: :environment do |_task, _args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 60000')

    profiles = Profile.where(
      fraud_pending_reason: nil,
    ).where(
      'fraud_review_pending_at IS NOT NULL OR fraud_rejection_at IS NOT NULL',
    )
    profiles.each do |profile|
      fraud_pending_reason = case profile.proofing_components&.[]('threatmetrix_review_status')
                             when 'review'
                               'threatmetrix_review'
                             when 'reject'
                               'threatmetrix_reject'
                             else
                               'threatmetrix_review'
                             end
      warn "#{profile.id},#{fraud_pending_reason}"
      profile.update!(fraud_pending_reason: fraud_pending_reason)
    end
  end

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
