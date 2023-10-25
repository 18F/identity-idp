# frozen_string_literal: true

module MultiRegionKmsMigration
  class UserMigrationJob < ApplicationJob
    queue_as :long_running

    MAXIMUM_ERROR_TOLERANCE = 10

    include ::NewRelic::Agent::MethodTracer

    def perform(statement_timeout: 120, user_count: 1000)
      return unless IdentityConfig.store.multi_region_kms_migration_jobs_enabled

      error_count = 0
      success_count = 0

      users = find_users_to_migrate(statement_timeout:, user_count:)
      users.each do |user|
        return if error_count >= MAXIMUM_ERROR_TOLERANCE # rubocop:disable Lint/NonLocalExitFromIterator

        Encryption::MultiRegionKmsMigration::UserMigrator.new(user).migrate!
        success_count += 1
        analytics.multi_region_kms_migration_user_migrated(
          success: true,
          user_id: user.id,
          exception: nil,
        )
      rescue => err
        error_count += 1
        analytics.multi_region_kms_migration_user_migrated(
          success: false,
          user_id: user.id,
          exception: err.inspect,
        )
      end
      analytics.multi_region_kms_migration_user_migration_summary(
        user_count: users.size,
        success_count: success_count,
        error_count: error_count,
      )
    end

    def find_users_to_migrate(statement_timeout:, user_count:)
      User.transaction do
        quoted_timeout = User.connection.quote(statement_timeout * 1000)
        User.connection.execute("SET LOCAL statement_timeout = #{quoted_timeout}")

        password_scope = User.where.not(
          encrypted_password_digest: '',
        ).where(
          'encrypted_password_digest IS NOT NULL',
        ).where(
          encrypted_password_digest_multi_region: nil,
        ).where(
          'encrypted_password_digest NOT LIKE ?', '%encryption_key%'
        )
        personal_key_scope = User.where.not(
          encrypted_recovery_code_digest: '',
        ).where(
          'encrypted_recovery_code_digest IS NOT NULL',
        ).where(
          encrypted_recovery_code_digest_multi_region: nil,
        ).where(
          'encrypted_recovery_code_digest NOT LIKE ?', '%encryption_key%'
        )

        password_scope.or(personal_key_scope).limit(user_count).to_a
      end
    end

    def analytics
      @analytics ||= Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
    end

    add_method_tracer :find_users_to_migrate, "Custom/#{name}/find_users_to_migrate"
  end
end
