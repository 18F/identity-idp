namespace :profiles do
  desc 'Pass a user that has a pending review'

  task backfill_fraud_timestamps: :environment do |_task, _args|
    Profile.where.not(fraud_review_pending_at: nil).each do |profile|
      puts "Backfilling fraud_reviewing_at for profile #{profile.id}"
      fraud_review_pending_at = profile.fraud_review_pending_at
      profile.update(fraud_reviewing_at: fraud_review_pending_at)
    end

    Profile.where.not(fraud_rejection_at: nil).each do |profile|
      puts "Backfilling fraud_rejected_at for profile #{profile.id}"
      fraud_rejection_at = profile.fraud_rejection_at
      profile.update(fraud_rejected_at: fraud_rejection_at)
    end
  end
end
