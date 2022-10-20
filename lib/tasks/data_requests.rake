namespace :data_requests do
  # UUIDS=123abc,456def rake data_requests:lookup_users_by_device
  desc 'Recursively lookup users using a network of shared devices'
  task lookup_users_by_device: :environment do
    ActiveRecord::Base.connection.execute('SET statement_timeout = 0')

    uuids = ENV.fetch('UUIDS', '').split(',')
    users = uuids.map { |uuid| DataRequests::LookupUserByUuid.new(uuid).call }.compact

    users = DataRequests::LookupSharedDeviceUsers.new(users).call
    puts "UUIDS: #{users.map(&:uuid).join(',')}"
  end

  # UUIDS=123abc,456def REQUESTING_ISSUER=sample:app:issuer rake data_requests:create_users_report
  desc 'Create a JSON report with data for the specified users'
  task create_users_report: :environment do
    uuids = ENV.fetch('UUIDS', '').split(',')
    requesting_issuers = ENV.fetch('REQUESTING_ISSUER', nil)&.split(',')

    output = uuids.map do |uuid|
      user = DataRequests::LookupUserByUuid.new(uuid).call
      next warn("No record for uuid #{uuid}") if user.nil?
      DataRequests::CreateUserReport.new(user, requesting_issuers).call
    end.compact.to_json
    puts output
  end

  # export USERS_REPORT=/tmp/query-2020-11-17/user_report.json
  # export OUTPUT_DIR=/tmp/query-2020-11-17/results/
  # rake data_requests:process_users_report
  desc 'Take a JSON user report, download logs from cloud watch, and write user data'
  task process_users_report: :environment do
    users_report = JSON.parse(File.read(ENV['USERS_REPORT']), symbolize_names: true)
    output_dir = ENV['OUTPUT_DIR']

    users_report.each do |user_report|
      puts "Processing user: #{user_report[:requesting_issuer_uuid]}"
      user_output_dir = File.join(output_dir, user_report[:requesting_issuer_uuid])
      FileUtils.mkdir_p(user_output_dir)

      DataRequests::WriteUserInfo.new(user_report, user_output_dir).call
      DataRequests::WriteUserEvents.new(
        user_report, user_output_dir, user_report[:requesting_issuer_uuid]
      ).call

      cloudwatch_dates = user_report[:user_events].pluck(:date_time).map do |date_time|
        Time.zone.parse(date_time).to_date
      end.uniq
      cloudwatch_results = DataRequests::FetchCloudwatchLogs.new(
        user_report[:login_uuid],
        cloudwatch_dates,
      ).call

      DataRequests::WriteCloudwatchLogs.new(cloudwatch_results, user_output_dir).call
    end
  end

  #temporary thing for a one-off
  desc 'Percentages of overall users with different MFA types configured'
  task user_mfa_percentages: :environment do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    CSV.open('/tmp/mfa_counts.csv', 'w') do |csv|
      csv << %w[phone webauthn webauthn_platform backup_codes piv_cac auth_app]
      User.includes(
        :phone_configurations,
        :webauthn_configurations,
        :backup_code_configurations,
        :piv_cac_configurations,
        :auth_app_configurations
      ).find_in_batches do |batch|
        batch.each do |user|
          phone_count, webauthn_count, webauthn_platform_count, backup_codes_count, piv_cac_count, auth_app_count = 0, 0, 0, 0, 0, 0
          phone_count += 1 if user.phone_configurations.select(&:mfa_enabled?).any?
          webauthn_count += 1 if user.webauthn_configurations.select do |w|
            w.mfa_enabled? && (w.friendly_name == :webauthn)
          end.any?
          webauthn_platform_count += 1 if user.webauthn_configurations.select do |w|
            w.mfa_enabled? && (w.friendly_name == :webauthn)
          end.any?
          backup_codes_count += 1 if user.backup_code_configurations.first.present? # collapses all rows into 1
          piv_cac_count += 1 if user.piv_cac_configurations.select(&:mfa_enabled?).any?
          auth_app_count += 1 if user.auth_app_configurations.select(&:mfa_enabled?).any?

          csv << [phone_count, webauthn_count, webauthn_platform_count, backup_codes_count, piv_cac_count, auth_app_count]
        end
      end
    end

    phone_total, webauthn_total, webauthn_platform_total, backup_codes_total, piv_cac_total, auth_app_total = 0, 0, 0, 0, 0, 0
    total = 0

    CSV.foreach('/tmp/mfa_counts.csv', headers: true) do |r|
      total += 1
      phone_total += r['phone'].to_i
      webauthn_total += r['webauthn'].to_i
      webauthn_platform_total += r['webauthn_platform'].to_i
      backup_codes_total += r['backup_codes'].to_i
      piv_cac_total += r['piv_cac'].to_i
      auth_app_total += r['auth_app'].to_i
    end
    puts "total: #{total}"
    phone_percentage = (phone_total.to_f / total) * 100
    webauthn_percentage = (webauthn_total.to_f / total) * 100
    webauthn_platform_percentage = (webauthn_platform_total.to_f / total) * 100
    backup_codes_percentage = (backup_codes_total.to_f / total) * 100
    piv_cac_percentage = (piv_cac_total.to_f / total) * 100
    auth_app_percentage = (auth_app_total.to_f / total) * 100

    CSV.open('/tmp/mfa_percentages.csv', 'w') do |csv|
      csv << %w[phone webauthn webauthn_platform backup_codes piv_cac auth_app]
      csv << [phone_percentage, webauthn_percentage, webauthn_platform_percentage, backup_codes_percentage, piv_cac_percentage, auth_app_percentage]
    end
  end
end
