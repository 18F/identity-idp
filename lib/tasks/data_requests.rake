# frozen_string_literal: true

namespace :data_requests do
  # UUIDS=123abc,456def rake data_requests:lookup_users_by_device
  desc 'Recursively lookup users using a network of shared devices'
  task lookup_users_by_device: :environment do
    require 'data_requests/deployed'

    ActiveRecord::Base.connection.execute('SET statement_timeout = 0')

    uuids = ENV.fetch('UUIDS', '').split(',')
    users = uuids.map { |uuid| DataRequests::Deployed::LookupUserByUuid.new(uuid).call }.compact

    users = DataRequests::Deployed::LookupSharedDeviceUsers.new(users).call
    puts "UUIDS: #{users.map(&:uuid).join(',')}"
  end

  # UUIDS=123abc,456def REQUESTING_ISSUER=sample:app:issuer rake data_requests:create_users_report
  desc 'Create a JSON report with data for the specified users'
  task create_users_report: :environment do
    require 'data_requests/deployed'

    uuids = ENV.fetch('UUIDS', '').split(',')
    requesting_issuers = ENV.fetch('REQUESTING_ISSUER', nil)&.split(',')

    output = uuids.map do |uuid|
      user = DataRequests::Deployed::LookupUserByUuid.new(uuid).call
      next warn("No record for uuid #{uuid}") if user.nil?
      DataRequests::Deployed::CreateUserReport.new(user, requesting_issuers).call
    end.compact.to_json
    puts output
  end

  # export USERS_REPORT=/tmp/query-2020-11-17/user_report.json
  # export OUTPUT_DIR=/tmp/query-2020-11-17/results/
  # rake data_requests:process_users_report
  desc 'Take a JSON user report, download logs from cloud watch, and write user data'
  task process_users_report: :environment do
    require 'data_requests/local'

    users_report = JSON.parse(File.read(ENV['USERS_REPORT']), symbolize_names: true)
    output_dir = ENV['OUTPUT_DIR']

    users_report.each do |user_report|
      puts "Processing user: #{user_report[:requesting_issuer_uuid]}"
      user_output_dir = File.join(output_dir, user_report[:requesting_issuer_uuid])
      FileUtils.mkdir_p(user_output_dir)

      DataRequests::Local::WriteUserInfo.new(user_report, user_output_dir).call
      DataRequests::Local::WriteUserEvents.new(
        user_report, user_output_dir, user_report[:requesting_issuer_uuid]
      ).call

      cloudwatch_dates = user_report[:user_events].pluck(:date_time).map do |date_time|
        Time.zone.parse(date_time).to_date
      end.uniq
      cloudwatch_results = DataRequests::Local::FetchCloudwatchLogs.new(
        user_report[:login_uuid],
        cloudwatch_dates,
      ).call

      DataRequests::Local::WriteCloudwatchLogs.new(cloudwatch_results, user_output_dir).call
    end
  end
end
