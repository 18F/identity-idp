namespace :db do
  desc 'Grant readonly database user read access to all tables'
  task grant_readonly_access: :environment do
    username = IdentityConfig.store.database_readonly_username

    if username.blank?
      warn 'Skipping readonly db setup because read only user is not present'
      next
    end

    sql = "GRANT SELECT ON ALL TABLES IN SCHEMA public TO #{username}"

    ActiveRecord::Base.connection.execute(sql)
  end

  desc 'Create a readonly database user'
  task create_readonly_user: :environment do
    username = IdentityConfig.store.database_readonly_username

    if username.blank?
      warn 'Skipping readonly db setup because read only user is not present'
      next
    end

    password = IdentityConfig.store.database_readonly_password
    sql_statements = [
      format(
        "CREATE USER %s WITH ENCRYPTED PASSWORD '%s'",
        username,
        password,
      ),
      format(
        'GRANT SELECT ON ALL TABLES IN SCHEMA public TO %s',
        username,
      ),
    ]
    sql_statements.each { |sql| ActiveRecord::Base.connection.execute(sql) }
  end
end
