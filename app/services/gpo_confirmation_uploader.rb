class GpoConfirmationUploader
  def initialize
    @now = Time.zone.now
  end

  def run
    confirmations = GpoConfirmation.all.to_a
    export = generate_export(confirmations)
    upload_export(export)
    LetterRequestsToGpoFtpLog.create(ftp_at: @now, letter_requests_count: confirmations.count)
    clear_confirmations(confirmations)
  rescue StandardError => error
    NewRelic::Agent.notice_error(error)
  end

  private

  def generate_export(confirmations)
    GpoConfirmationExporter.new(confirmations).run
  end

  def upload_export(export)
    return unless FeatureManagement.gpo_upload_enabled?
    io = StringIO.new(export)
    Net::SFTP.start(*sftp_config) do |sftp|
      sftp.upload!(io, remote_path)
    end
  end

  def clear_confirmations(confirmations)
    GpoConfirmation.where(id: confirmations.map(&:id)).destroy_all
  end

  def remote_path
    timestamp = @now.strftime('%Y%m%d')
    File.join(env.usps_upload_sftp_directory, "batch#{timestamp}.psv")
  end

  def sftp_config
    [
      env.usps_upload_sftp_host,
      env.usps_upload_sftp_username,
      password: env.usps_upload_sftp_password,
      timeout: env.usps_upload_sftp_timeout.to_i,
    ]
  end

  def env
    AppConfig.env
  end
end
