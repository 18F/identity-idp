namespace :profiles do
  desc 'If a profile is in review or rejected, store timestamp as updated_at'

  task backfill_fraud_timestamps_from_booleans: :environment do |_task, _args|
    Profile.where.not(fraud_review_pending: nil).each do |profile|
      puts "Backfilling fraud_reviewing_at for profile #{profile.id}"
      updated_at = profile.updated_at
      profile.update(fraud_reviewing_at: updated_at)
    end

    Profile.where.not(fraud_rejection: nil).each do |profile|
      puts "Backfilling fraud_rejected_at for profile #{profile.id}"
      updated_at = profile.updated_at
      profile.update(fraud_rejected_at: updated_at)
    end
  end
end
