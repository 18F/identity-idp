class IrsAttemptsEventsBatchJob < ApplicationJob
  queue_as :default

  def perform(subject_timestamp = Time.zone.now - 1.hour, dir_path = './attempts_api_output')
    return nil unless IdentityConfig.store.irs_attempt_api_enabled

    events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: subject_timestamp)
    event_values = events.values.join("\r\n")

    decoded_key_der = Base64.strict_decode64(IdentityConfig.store.irs_attempt_api_public_key)
    pub_key = OpenSSL::PKey::RSA.new(decoded_key_der)

    result = IrsAttemptsApi::EnvelopeEncryptor.encrypt(
      data: event_values, timestamp: subject_timestamp, public_key: pub_key,
    )

    # write to a file and store on the disk until S3 is setup
    begin
      Dir.mkdir(dir_path) unless File.exist?(dir_path)

      file = File.open("#{dir_path}/#{result.filename}", 'wb')
      file.write(result.encrypted_data)
    rescue IOError => e
      Rails.logger.debug e
    ensure
      file&.close
    end
    return file.path

    # Write the file to S3 instead of whatever dir_path winds up being
  end
end
