class UndeliverableAddressNotifier
  TEMP_FILE_BASENAME = 'usps_bounced'.freeze

  def call
    temp_file = download_file
    notifications_sent = process_file_and_send_notifications(temp_file)
    cleanup(temp_file)
    notifications_sent
  end

  private

  def download_file
    file = Tempfile.new(TEMP_FILE_BASENAME)
    Net::SFTP.start(*sftp_config) do |sftp|
      sftp.download!(Figaro.env.usps_download_sftp_directory, file.path)
    end
    file
  end

  def cleanup(file)
    file.close
    file.unlink
  end

  def process_file_and_send_notifications(file)
    notifications_sent = 0
    File.readlines(file.path).each do |line|
      code = line.chomp
      sent = update_bounced_at_and_send_notification(code)
      notifications_sent += 1 if sent
    end
    notifications_sent
  end

  def update_bounced_at_and_send_notification(otp)
    ucc = UspsConfirmationCode.find_by(otp_fingerprint: Pii::Fingerprinter.fingerprint(otp))
    return if ucc.nil?
    ucc.with_lock do
      return if ucc.bounced_at
      ucc.update(bounced_at: Time.zone.now)
      send_email(ucc.profile.user)
    end
    true
  end

  def send_email(user)
    user.confirmed_email_addresses.each do |email_address|
      UserMailer.undeliverable_address(email_address).deliver_later
    end
  end

  def sftp_config
    [
      env.usps_download_sftp_host,
      env.usps_download_sftp_username,
      password: env.usps_download_sftp_password,
      timeout: env.usps_download_sftp_timeout.to_i,
    ]
  end

  def env
    Figaro.env
  end

  def usps_confirmation_code(otp)
    @ucc ||= UspsConfirmationCode.find_by(otp_fingerprint: Pii::Fingerprinter.fingerprint(otp))
  end
end
