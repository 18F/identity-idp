# frozen_string_literal: true

class FraudOpsS3BatchJob < ApplicationJob
  queue_as :default

  def perform(batch_size: 1000)
    return unless IdentityConfig.store.fraud_ops_tracker_enabled

    redis_client = FraudOpsRedisClient.new

    events = redis_client.read_all_events(batch_size: batch_size)

    if events.any?
      uploaded_count = upload_events_to_s3(events)

      if uploaded_count > 0
        deleted_count = redis_client.delete_events(keys: events.keys)

        Rails.logger.info(
          "FraudOpsS3BatchJob: Uploaded #{uploaded_count} events to S3, " \
          "deleted #{deleted_count} events from Redis",
        )
      end
    end

    expired_count = redis_client.clear_expired_keys
    Rails.logger.info("FraudOpsS3BatchJob: Cleaned up #{expired_count} expired Redis keys") if expired_count > 0
  end

  private

  def upload_events_to_s3(events)
    return 0 if events.empty? || s3_bucket.blank?

    timestamp = Time.zone.now
    filename = "fraud-ops-events/#{timestamp.strftime('%Y/%m/%d')}/events-#{timestamp.to_i}-#{SecureRandom.hex(4)}.json"

    batch_data = {
      batch_timestamp: timestamp.iso8601,
      event_count: events.count,
      events: events.map { |jti, encrypted_data| { jti: jti, encrypted_data: encrypted_data } },
    }

    begin
      s3_client.put_object(
        bucket: s3_bucket,
        key: filename,
        body: batch_data.to_json,
        content_type: 'application/json',
        server_side_encryption: 'AES256',
      )

      Rails.logger.info("FraudOpsS3BatchJob: Successfully uploaded #{events.count} events to s3://#{s3_bucket}/#{filename}")
      events.count
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("FraudOpsS3BatchJob: Failed to upload events to S3: #{e.message}")
      0
    end
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      region: IdentityConfig.store.aws_region,
    )
  end

  def s3_bucket
    IdentityConfig.store.s3_idp_dw_tasks
  end
end
