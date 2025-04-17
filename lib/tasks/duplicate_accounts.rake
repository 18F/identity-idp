# frozen_string_literal: true

require 'csv'

namespace :duplicate_accounts do
  task :report, %i[service_provider] => [:environment] do |_task, args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 0')
    puts 'User uuid, Service Provider, Agency, Latest Activity, Profile Activated'

    results = DuplicateAccountsReport.call(args[:service_provider])

    results_to_csv(results)
    results.each do |result|
      result_str = "#{result['uuid']}, "\
                "#{result['service_provider']}, "\
                "#{result['friendly_name']}, "\
                "#{result['updated_at']}, "\
                "#{result['activated_at']}"
      puts result_str
    end
  end

  def results_to_csv(results)
    puts 'result to csv'
    output_dir = './tmp/duplicate_accounts/'
    FileUtils.mkdir_p(output_dir)
    accounts_csv = CSV.open(File.join(output_dir, 'duplicate_accounts.csv'), 'w')

    accounts_csv << %w[
      user_uuid
      service_provider
      agency
      latest_activity
      profile_activated
    ]

    results.each do |result|
      accounts_csv << [
        result['uuid'],
        result['service_provider'],
        result['friendly_name'],
        result['updated_at'],
        result['activated_at'],
      ]
    end
  end
end
# rake "duplicate_accounts:report["urn:gov:gsa:SAML:2.0.profiles:sp:sso:localhost"]"
