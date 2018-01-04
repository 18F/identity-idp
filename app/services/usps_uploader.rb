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
      Rails.root.join('tmp', "batch-#{timestamp}.pgp")
    end
  end

  private

  def build_file
    UspsExporter.new(local_path).run
  end

  def upload_file
    env = Figaro.env

    Net::SFTP.start(
      env.equifax_sftp_host,
      env.equifax_sftp_username,
      key_data: [RequestKeyManager.equifax_ssh_key.to_pem]
    ) do |sftp|
      sftp.upload!(local_path.to_s, remote_path)
    end
  end

  def clear_file
    FileUtils.rm(local_path)
  end

  def remote_path
    File.join(Figaro.env.equifax_sftp_directory, 'batch.pgp')
  end
end
