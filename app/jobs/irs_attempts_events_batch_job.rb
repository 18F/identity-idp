class IrsAttemptsEventsBatchJob < ApplicationJob
  queue_as :default

  def perform(timestamp = Time.zone.now - 1.hour)
    enabled = IdentityConfig.store.irs_attempt_api_enabled &&
              IdentityConfig.store.irs_attempt_api_aws_s3_enabled &&
              IdentityConfig.store.irs_attempt_api_bucket_name
    return nil unless enabled

    events = redis_client.read_events(timestamp: timestamp)
    event_values = events.values.join("\r\n")

    public_key = IdentityConfig.store.irs_attempt_api_public_key

    result = IrsAttemptsApi::EnvelopeEncryptor.encrypt(
      data: event_values, timestamp: timestamp, public_key_str: public_key,
    )

    bucket_name = IdentityConfig.store.irs_attempt_api_bucket_name

    create_and_upload_to_attempts_s3_resource(
      bucket_name: bucket_name, filename: result.filename,
      encrypted_data: result.encrypted_data
    )

    encoded_iv = Base64.strict_encode64(result.iv)
    encoded_encrypted_key = Base64.strict_encode64(result.encrypted_key)

    IrsAttemptApiLogFile.create(
      filename: result.filename,
      iv: encoded_iv,
      encrypted_key: encoded_encrypted_key,
      requested_time: redis_client.key(timestamp),
    )
  end

  def create_and_upload_to_attempts_s3_resource(bucket_name:, filename:, encrypted_data:)
    aws_object = Aws::S3::Resource.new.bucket(bucket_name).object(filename)
    aws_object.put(body: encrypted_data, acl: 'private', content_type: 'text/plain')
  end

  def redis_client
    @redis_client ||= IrsAttemptsApi::RedisClient.new
  end
end
