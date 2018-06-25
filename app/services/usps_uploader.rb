class UspsUploader
  def run
    build_file
    upload_file
    clear_file
  rescue StandardError => error
    NewRelic::Agent.notice_error(error)
  end

  # @api private
  def local_path
    @_local_path ||= begin
      timestamp = Time.zone.now.strftime('%Y%m%d%H%M%S')
      Rails.root.join('tmp', "batch-#{timestamp}.psv")
    end
  end

  private

  def build_file
    UspsExporter.new(local_path).run
  end

  def upload_file
    Net::SFTP.start(
      env.usps_upload_sftp_host,
      env.usps_upload_sftp_username,
      password: env.usps_upload_sftp_password
    ) do |sftp|
      sftp.upload!(local_path.to_s, remote_path)
    end
  end

  def clear_file
    FileUtils.rm(local_path)
  end

  def remote_path
    File.join(Figaro.env.usps_upload_sftp_directory, 'batch.psv')
  end

  def env
    Figaro.env
  end
end
