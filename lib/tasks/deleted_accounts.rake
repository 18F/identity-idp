namespace :deleted_accounts do
  task :report, %i[service_provider days_ago] => [:environment] do |_task, args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 0')
    puts 'last_authenticated_at, identity_uuid'
    days_ago = args[:days_ago].to_i
    rows = DeletedAccountsReport.call(args[:service_provider], args[:days_ago])
    rows.each do |row|
      puts "#{row['last_authenticated_at']}, #{row['identity_uuid']}"
    end
    puts "Total records=#{rows.count} Date range=#{days_ago.days.ago} - #{Time.zone.now}"
  end
end
# rake "deleted_accounts:report[urn:gov:gsa:openidconnect:sp:sinatra,30]"
