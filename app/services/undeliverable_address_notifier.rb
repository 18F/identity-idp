class UndeliverableAddressNotifier
  TEMP_FILE_BASENAME = 'gpo_bounced'.freeze

  def call
    temp_file = download_file
    notifications_sent = process_file(temp_file)
    cleanup(temp_file)
    notifications_sent
  end

  private

  attr_accessor :ucc

  def download_file
    file = Tempfile.new(TEMP_FILE_BASENAME)
    Net::SFTP.start(*sftp_config) do |sftp|
      sftp.download!(AppConfig.env.usps_download_sftp_directory, file.path)
    end
    file
  end

  def cleanup(file)
    file.close
    file.unlink
  end

  def process_file(file)
    notifications_sent = 0
    File.readlines(file.path).each do |line|
      code = line.chomp
      sent = process_code(code)
      notifications_sent += 1 if sent
    end
    notifications_sent
  end

  def process_code(otp)
    gpo_confirmation_code(otp)&.safe_update_bounced_at_and_send_notification
  end

  def sftp_config
    [
      env.usps_download_sftp_host,
      env.usps_download_sftp_username,
      password: env.usps_download_sftp_password,
      timeout: IdentityConfig.store.usps_download_sftp_timeout,
    ]
  end

  def env
    AppConfig.env
  end

  def gpo_confirmation_code(otp)
    @ucc ||= GpoConfirmationCode.find_by(otp_fingerprint: Pii::Fingerprinter.fingerprint(otp))
  end
end
