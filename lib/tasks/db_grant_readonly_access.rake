namespace :db do
  desc 'Create a readonly database user'
  task grant_readonly_access: :environment do
    username = Figaro.env.database_readonly_username

    if username.blank?
      warn 'Skipping readonly db setup because read only user is not present'
      next
    end

    sql = "GRANT SELECT ON ALL TABLES IN SCHEMA public TO #{username}"

    ActiveRecord::Base.connection.execute(sql)
  end
end
