class IrsAttemptsEventsBatchJob < ApplicationJob
  queue_as :default

  def perform(timestamp = Time.zone.now - 1.hour, dir_path: './attempts_api_output')
    return nil unless IdentityConfig.store.irs_attempt_api_enabled

    events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: timestamp)
    event_values = events.values.join("\r\n")

    decoded_key_der = Base64.strict_decode64(IdentityConfig.store.irs_attempt_api_public_key)
    pub_key = OpenSSL::PKey::RSA.new(decoded_key_der)

    result = IrsAttemptsApi::EnvelopeEncryptor.encrypt(
      data: event_values, timestamp: timestamp, public_key: pub_key,
    )

    # Write the file to S3 - Can we skip the file write step? Do we need to write out a temp file?
    if IdentityConfig.store.irs_attempt_api_bucket_name.nil?
      # write to a file and store on the disk until S3 is setup
      FileUtils.mkdir_p(dir_path)

      file_path = "#{dir_path}/#{result.filename}"

      File.open(file_path, 'wb') do |file|
        file.write(result.encrypted_data)
      end
      return { encryptor_result: result, file_path: file_path }
    else
      bucket_name = IdentityConfig.store.irs_attempt_api_bucket_name
      bucket_url = "s3://#{bucket_name}/#{result.filename}"

      puts "uploading to #{bucket_url}"

      aws_object = Aws::S3::Resource.new.bucket(bucket_name).object(result.filename)
      aws_object.put(body: result.encrypted_data, acl: 'private', content_type: 'text/plain')

      puts "upload completed to #{bucket_url}"

      IrsAttemptApiLogFile.create(
        filename: bucket_url, iv: result.iv,
        encrypted_key: result.encrypted_key, requested_time: timestamp
      )
    end
  end
end
