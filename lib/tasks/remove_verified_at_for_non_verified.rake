# frozen_string_literal: true

namespace :profiles do
  desc 'Remove verified_at if a profile is gpo, fraud pending or fraud rejected'

  ##
  # Usage:
  #
  # Print errant profiles
  # bundle exec rake profiles:remove_verified_at_from_non_verified_profiles
  #
  # Commit updates
  # bundle exec rake profiles:remove_verified_at_from_non_verified_profiles UPDATE_PROFILES=true
  #
  task remove_verified_at_from_non_verified_profiles: :environment do |_task, _args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 60000')

    update_profiles = ENV['UPDATE_PROFILES'] == 'true'

    profiles = Profile.where('verified_at IS NOT NULL').
      where('fraud_review_pending_at IS NOT NULL OR fraud_rejection_at IS NOT NULL OR
        gpo_verification_pending_at IS NOT NULL')

    profiles.each do |profile|
      warn "#{profile.id},#{profile.verified_at}, #{profile.user.uuid}"
      profile.update!(verified_at: nil) if update_profiles
    end
  end

  ##
  # Usage:
  #
  # Rollback the above:
  #
  # export BACKFILL_OUTPUT='<backfill_output>'
  # bundle exec rake profiles:rollback_remove_verified_at_from_non_verified_profiles
  #
  task rollback_remove_verified_at_from_non_verified_profiles: :environment do |_task, _args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 60000')

    profiles = ENV['VERIFIED_OUTPUT']

    warn "Updating #{profiles.count} records"

    profiles.split("\n").map do |profile_row|
      profile_id, profile_verified_at = profile_row.split(',', 2)

      Profile.find(profile_id).update(verified_at: profile_verified_at)
    end
  end

  ##
  # Usage:
  # bundle exec rake profiles:validate_remove_verified_at_from_non_verified_profiles
  #
  task validate_remove_verified_at_from_non_verified_profiles: :environment do |_task, _args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 60000')

    profiles = Profile.where(
      verified_at: nil,
    ).where('fraud_review_pending_at IS NOT NULL OR fraud_rejection_at IS NOT NULL OR
        gpo_verification_pending_at IS NOT NULL')

    if profiles.empty?
      warn 'remove verified_at from profiles that were not verified was successful'
    else
      warn "remove verified_at from profiles that were not verified left #{profiles.count} rows"
    end
  end
end
