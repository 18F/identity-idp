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
  #
  # Optionally filter by start and/or end date
  # export START_DATE=2024-01-01
  # export END_DATE=2025-01-01
  #
  # rake data_requests:process_users_report
  desc 'Take a JSON user report, download logs from cloud watch, and write user data'
  task process_users_report: :environment do
    require 'data_requests/local'

    users_report = JSON.parse(File.read(ENV['USERS_REPORT']), symbolize_names: true)
    output_dir = ENV['OUTPUT_DIR']
    start_date = Time.zone.parse(ENV['START_DATE']).to_date if ENV['START_DATE']
    end_date = Time.zone.parse(ENV['END_DATE']).to_date if ENV['END_DATE']

    users_csv = CSV.open(File.join(output_dir, 'users.csv'), 'w')
    user_events_csv = CSV.open(File.join(output_dir, 'user_events.csv'), 'w')
    logs_csv = CSV.open(File.join(output_dir, 'logs.csv'), 'w')

    users_report.each_with_index do |user_report, idx|
      puts "Processing user: #{user_report[:requesting_issuer_uuid]}"

      DataRequests::Local::WriteUserInfo.new(
        user_report:,
        csv: users_csv,
        include_header: idx == 0,
      ).call

      DataRequests::Local::WriteUserEvents.new(
        user_report:,
        requesting_issuer_uuid: user_report[:requesting_issuer_uuid],
        csv: user_events_csv,
        include_header: idx == 0,
      ).call

      cloudwatch_dates = user_report[:user_events].pluck(:date_time).map do |date_time|
        Time.zone.parse(date_time).to_date
      end.uniq.filter do |date|
        if start_date && date < start_date
          false
        elsif end_date && date > end_date
          false
        else
          true
        end
      end

      cloudwatch_results =
        if cloudwatch_dates.empty?
          []
        else
          DataRequests::Local::FetchCloudwatchLogs.new(
            user_report[:login_uuid],
            cloudwatch_dates,
          ).call
        end

      DataRequests::Local::WriteCloudwatchLogs.new(
        cloudwatch_results:,
        requesting_issuer_uuid: user_report[:requesting_issuer_uuid],
        csv: logs_csv,
        include_header: idx == 0,
      ).call

      users_csv.flush
      user_events_csv.flush
      logs_csv.flush
    end
  ensure
    users_csv&.close
    user_events_csv&.close
    logs_csv&.close
  end
end
