module MultiRegionKmsMigration
  class ProfileMigrationJob < ApplicationJob
    include ::NewRelic::Agent::MethodTracer

    def perform(statement_timeout: 120, profile_count: 1000)
      find_profiles_to_migrate(statement_timeout:, profile_count:).each do |profile|
        # TODO Some kind of logging
        Encryption::MultiRegionKmsMigration::ProfileMigrator.new(profile).migrate!
      rescue => err
        warn "Whoops #{err}"
        # TODO The above, but better
      end
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

    add_method_tracer :find_profiles_to_migrate, "Custom/#{name}/find_profiles_to_migrate"
  end
end
