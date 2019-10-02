namespace :identities do
  task update_ial_column: :environment do |_task|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 0')
    Identity.where(ial: 3).update_all(ial: 2)
  end
end
