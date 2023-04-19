namespace :profiles do
  desc 'If a profile is in review or rejected, store corresponding timestamp as updated_at'

  task backfill_fraud_timestamps_from_booleans: :environment do |_task, _args|
    # Beware large result sets
    Profile.where(fraud_review_pending: true, fraud_review_pending_at: nil).each do |profile|
      puts "Backfilling fraud_review_pending_at for profile #{profile.id}"
      updated_at = profile.updated_at
      profile.update(fraud_review_pending_at: updated_at)
    end

    # Beware large result sets
    Profile.where(fraud_rejection: true, fraud_rejection_at: nil).each do |profile|
      puts "Backfilling fraud_rejection_at for profile #{profile.id}"
      updated_at = profile.updated_at
      profile.update(fraud_rejection_at: updated_at)
    end
  end
end
