module MultiRegionKmsMigration
  class ProfileMigrationJob < ApplicationJob
    include ::NewRelic::Agent::MethodTracer

    def perform(statement_timeout: 120, profile_count: 1000)
      profiles = find_profiles_to_migrate(statement_timeout:, profile_count:)
      profiles.each do |profile|
        Encryption::MultiRegionKmsMigration::ProfileMigrator.new(profile).migrate!
        analyitcs.multi_region_kms_migration_profile_migrated(
          success: true,
          profile_id: profile.id,
          exception: nil,
        )
      rescue => err
        analyitcs.multi_region_kms_migration_profile_migrated(
          success: false,
          profile_id: profile.id,
          exception: err.inspect,
        )
      end
      analyitcs.multi_region_kms_migration_profile_migration_summary(
        profile_count: profiles.size,
      )
    end

    def find_profiles_to_migrate(statement_timeout:, profile_count:)
      Profile.transaction do
        quoted_timeout = Profile.connection.quote(statement_timeout * 1000)
        Profile.connection.execute("SET LOCAL statement_timeout = #{quoted_timeout}")

        Profile.where(
          encrypted_pii_multi_region: nil,
          encrypted_pii_recovery_multi_region: nil,
        ).limit(profile_count)
      end
    end

    def analyitcs
      @analytics ||= Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
    end

    add_method_tracer :find_profiles_to_migrate, "Custom/#{name}/find_profiles_to_migrate"
  end
end
