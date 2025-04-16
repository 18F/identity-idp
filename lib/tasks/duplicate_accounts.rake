# frozen_string_literal: true

namespace :duplicate_accounts do
  task :report, %i[service_provider] => [:environment] do |_task, args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 0')
    puts 'User uuid, Service Provider, Agency, Latest Activity, Profile Activated'

    rows = DuplicateAccountsReport.call(args[:service_provider])
    rows.each do |row|
      row_str = "#{row['uuid']}, "\
                "#{row['service_provider']}, "\
                "#{row['friendly_name']}, "\
                "#{row['updated_at']}, "\
                "#{row['activated_at']}"
      puts row_str
    end
  end
end
# rake "duplicate_accounts:report["urn:gov:gsa:SAML:2.0.profiles:sp:sso:localhost"]"
