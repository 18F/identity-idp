namespace :profiles do
  desc 'If a profile is in review or rejected, store the reason it was marked for fraud'

  task backfill_fraud_pending_reason: :environment do |_task, _args|
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
      profile.update!(fraud_pending_reason: fraud_pending_reason)
    end
  end
end
