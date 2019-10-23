namespace :db do
  desc 'Create a readonly database user'
  task grant_readonly_access: :environment do
    username = Figaro.env.database_readonly_username

    if username.blank?
      warn 'Skipping readonly db setup because read only user is not present'
      next
    end

    password = Figaro.env.database_readonly_password
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
