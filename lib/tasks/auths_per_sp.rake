namespace :auths_per_sp do
  task :report, %i[days_ago] => [:environment] do |_task, args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 0')
    puts 'agency, friendly_name, service_provider: count'
    rows = AuthsPerSpReport.call(args[:days_ago].to_i)
    rows.each do |row|
      puts "#{row['agency']}, #{row['friendly_name']}, #{row['service_provider']}: #{row['cnt']}"
    end
  end
end
# rake "auths_per_sp:report[30]"
