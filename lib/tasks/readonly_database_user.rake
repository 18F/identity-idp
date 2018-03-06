namespace :db do
  desc 'Create a readonly database user'
  task create_readonly_user: :environment do
    username = Figaro.env.database_readonly_username
    password = Figaro.env.database_readonly_password

    sql_statements = [
      "CREATE USER #{username} WITH ENCRYPTED PASSWORD '#{password}'",
      "GRANT SELECT ON ALL TABLES IN SCHEMA public TO #{username}",
    ]

    sql_statements.each { |sql| ActiveRecord::Base.connection.execute(sql) }
  end
end
