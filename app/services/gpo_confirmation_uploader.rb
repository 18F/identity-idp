class GpoConfirmationUploader
  class InvalidGpoConfirmationsPresent < StandardError; end

  def initialize(now = Time.zone.now)
    @now = now
  end

  def run
    export = generate_export(confirmations)
    upload_export(export)
    LetterRequestsToGpoFtpLog.create(ftp_at: @now, letter_requests_count: confirmations.count)
    clear_confirmations(confirmations)
  rescue StandardError => error
    NewRelic::Agent.notice_error(error)
    raise error
  end

  private

  def confirmations
    return @confirmations if defined?(@confirmations)

    all_confirmations = GpoConfirmation.all.to_a
    invalid_confirmations = all_confirmations.filter { |c| !c.valid? }

    if !invalid_confirmations.empty?
      NewRelic::Agent.notice_error(
        InvalidGpoConfirmationsPresent.new(
          "Found #{invalid_confirmations.length} invalid GPO confirmations.",
        ),
      )
    end

    @confirmations = all_confirmations - invalid_confirmations
  end

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
    timestamp = @now.strftime('%Y%m%d-%H%M%S')
    File.join(IdentityConfig.store.usps_upload_sftp_directory, "batch#{timestamp}.psv")
  end

  def sftp_config
    [
      IdentityConfig.store.usps_upload_sftp_host,
      IdentityConfig.store.usps_upload_sftp_username,
      password: IdentityConfig.store.usps_upload_sftp_password,
      timeout: IdentityConfig.store.usps_upload_sftp_timeout,
    ]
  end
end
