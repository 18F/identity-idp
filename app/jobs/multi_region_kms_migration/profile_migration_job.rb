module MultiRegionKmsMigration
  class ProfileMigrationJob < ApplicationJob
    MAXIMUM_ERROR_TOLERANCE = 10

    include ::NewRelic::Agent::MethodTracer

    def perform(statement_timeout: 120, profile_count: 1000)
      return unless IdentityConfig.store.multi_region_kms_migration_jobs_enabled

      error_count = 0
      success_count = 0

      profiles = find_profiles_to_migrate(statement_timeout:, profile_count:)
      profiles.each do |profile|
        return if error_count >= MAXIMUM_ERROR_TOLERANCE # rubocop:disable Lint/NonLocalExitFromIterator

        Encryption::MultiRegionKmsMigration::ProfileMigrator.new(profile).migrate!
        success_count += 1
        analytics.multi_region_kms_migration_profile_migrated(
          success: true,
          profile_id: profile.id,
          exception: nil,
        )
      rescue => err
        error_count += 1
        analytics.multi_region_kms_migration_profile_migrated(
          success: false,
          profile_id: profile.id,
          exception: err.inspect,
        )
      end
      analytics.multi_region_kms_migration_profile_migration_summary(
        profile_count: profiles.size,
        success_count: success_count,
        error_count: error_count,
      )
    end

    def find_profiles_to_migrate(statement_timeout:, profile_count:)
      Profile.transaction do
        quoted_timeout = Profile.connection.quote(statement_timeout * 1000)
        Profile.connection.execute("SET LOCAL statement_timeout = #{quoted_timeout}")

        Profile.where(
          encrypted_pii_multi_region: nil,
          encrypted_pii_recovery_multi_region: nil,
        ).where(
          'encrypted_pii IS NOT NULL',
          'encrypted_pii_recovery IS NOT NULL',
        ).limit(profile_count)
      end
    end

    def analytics
      @analytics ||= Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
    end

    add_method_tracer :find_profiles_to_migrate, "Custom/#{name}/find_profiles_to_migrate"
  end
end
