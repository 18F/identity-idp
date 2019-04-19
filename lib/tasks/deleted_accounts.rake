namespace :deleted_accounts do
  task :report, %i[service_provider days_ago] => [:environment] do |_task, args|
    puts 'uuid, last_authenticated_at'
    DeletedAccountsReport.call(args[:service_provider], args[:days_ago]).each do |row|
      puts "#{row['last_authenticated_at']}, #{row['uuid']}"
    end
  end
end
# rake "deleted_accounts:report[urn:gov:gsa:openidconnect:sp:sinatra,30]"
