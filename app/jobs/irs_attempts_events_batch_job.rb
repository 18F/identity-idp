class IrsAttemptsEventsBatchJob < ApplicationJob
  queue_as :default

  def perform(timestamp = Time.zone.now - 1.hour)
    return nil unless IdentityConfig.store.irs_attempt_api_enabled

    events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: timestamp)
    event_values = events.values.join("\r\n")

    decoded_key_der = Base64.strict_decode64(IdentityConfig.store.irs_attempt_api_public_key)
    pub_key = OpenSSL::PKey::RSA.new(decoded_key_der)

    result = IrsAttemptsApi::EnvelopeEncryptor.encrypt(
      data: event_values, timestamp: timestamp, public_key: pub_key,
    )

    # Write the file to S3 - Can we skip the file write step? Do we need to write out a temp file?
    bucket_name = IdentityConfig.store.irs_attempt_api_bucket_name
    bucket_url = "s3://#{bucket_name}/#{result.filename}"

    create_and_upload_to_attempts_s3_resource(bucket_name: bucket_name, filename: result.filename, encrypted_data: result.encrypted_data)

    encoded_iv = Base64.strict_encode64(result.iv)
    encoded_encrypted_key = Base64.strict_encode64(result.encrypted_key)

    IrsAttemptApiLogFile.create(
      filename: bucket_url, iv: encoded_iv,
      encrypted_key: encoded_encrypted_key, requested_time: timestamp
    )
  end

  def create_and_upload_to_attempts_s3_resource(bucket_name:, filename:, encrypted_data:)
    aws_object = Aws::S3::Resource.new.bucket(bucket_name).object(filename)
    aws_object.put(body: encrypted_data, acl: 'private', content_type: 'text/plain')
  end
end
