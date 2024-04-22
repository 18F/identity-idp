# frozen_string_literal: true

namespace :db do
  desc 'Create readonly database user and grant read access to all tables'
  task grant_readonly_access: :environment do
    username = IdentityConfig.store.database_readonly_username

    if username.blank?
      warn 'Skipping readonly db setup because read only user is not present'
      next
    end

    readonly_user_present = ActiveRecord::Base.connection.execute(
      "SELECT 1 FROM pg_roles WHERE rolname='#{username}'",
    )

    sql_statements = [
      format(
        'GRANT SELECT ON ALL TABLES IN SCHEMA public TO %s',
        username,
      ),
    ]

    password = IdentityConfig.store.database_readonly_password

    if !password.blank? && readonly_user_present.values.empty?
      sql_statements.unshift(
        format(
          "CREATE USER %s WITH ENCRYPTED PASSWORD '%s'",
          username,
          password,
        ),
      )
    end

    sql_statements.each { |sql| ActiveRecord::Base.connection.execute(sql) }
  end
end
