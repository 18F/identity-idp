class IrsAttemptsEventsBatchJob < ApplicationJob
  queue_as :default

  def perform(timestamp = Time.zone.now - 1.hour, dir_path = './attempts_api_batch_job_output')
    return nil unless IdentityConfig.store.irs_attempt_api_enabled

    events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: timestamp)
    event_values = events.values.join("\r\n")

    decoded_key_der = Base64.strict_decode64(IdentityConfig.store.irs_attempt_api_public_key)
    pub_key = OpenSSL::PKey::RSA.new(decoded_key_der)

    result = IrsAttemptsApi::EnvelopeEncryptor.encrypt(
      data: event_values, timestamp: timestamp, public_key: pub_key,
    )

    # write to a file and store on the disk until S3 is setup
    @file_path = ''
    if Dir.exist?(dir_path)
      @file_path = "#{dir_path}/#{result.filename}"

      File.open(@file_path, 'wb') do |file|
        file.write(result.encrypted_data)
      end
    else
      Dir.mktmpdir do |dir|
        @file_path = "#{dir}/#{result.filename}"

        File.open(@file_path, 'wb') do |file|
          file.write(result.encrypted_data)
        end
      end
    end

    return { encryptor_result: result, file_path: @file_path }

    # Write the file to S3 instead of whatever dir_path winds up being
  end
end
