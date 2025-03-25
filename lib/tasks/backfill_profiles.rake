# frozen_string_literal: true

namespace :profiles do
  desc 'Backfill the encrypted_pii_multi_region value column.'

  ##
  # Usage:
  #
  # Print pending updates
  # bundle exec rake profiles:backfill_encrypted_pii_multi_region
  #
  # Commit updates
  # bundle exec rake profiles:backfill_encrypted_pii_multi_region UPDATE_PROFILES=true
  #
  task backfill_encrypted_pii_multi_region: :environment do |_task, _args|
    profile_limit = ENV['PROFILE_LIMIT'].to_i
    statement_timeout_seconds = ENV['STATEMENT_TIMEOUT_SECONDS'].to_i
    update_profiles = ENV['UPDATE_PROFILES'] == 'true'

    profiles = Profile.transaction do
      quoted_timeout = Profile.connection.quote(statement_timeout_seconds * 1000)
      Profile.connection.execute("SET LOCAL statement_timeout = #{quoted_timeout}")

      Profile.where(
        <<-SQL,
        (encrypted_pii IS NOT NULL AND encrypted_pii_multi_region IS NULL) OR
        (encrypted_pii_recovery IS NOT NULL AND encrypted_pii_recovery_multi_region IS NULL)
        SQL
      ).limit(profile_limit)
    end

    Rails.logger.info("#{profiles.count} profiles found")
    profiles.each do |profile|
      Rails.logger.info(profile.id)
      Encryption::MultiRegionKmsProfileMigrator.new(profile).migrate! if update_profiles
    end
  end
end
