# frozen_string_literal: true

module AttemptsApi
  class FcmsTracker < Tracker
    include TrackerEvents
    attr_reader :current_user

    private

    def extra_attributes(event_type:)
      {
        agency_uuid: agency_uuid(event_type:),
        user_uuid: user&.uuid,
        user_id: user&.id,
        unique_session_id: user&.unique_session_id,
      }
    end

    def jwe(event)
      event.payload_json(issuer: sp.issuer)
    end

    def enabled?
      FeatureManagement.fcms_enabled?
    end

    def redis_client
      @redis_client ||= AttemptsApi::FcmsRedisClient.new
    end

    def public_key
      AppArtifacts.store.fcms_primary_public_key
    end

    def write_event(event)
      if FeatureManagement.fcms_s3_store?
        upload_file_to_s3_bucket(
          path: "#{key(event.occurred_at, sp.issuer)}/#{event.jti}",
          body: jwe(event),
          content_type:,
          bucket: IdentityConfig.store.s3_fcms_bucket_prefix,
        )
      else
        super
      end
    end

    def s3_client
      require 'aws-sdk-s3'

      @s3_client ||= Aws::S3::Client.new(
        http_open_timeout: 5,
        http_read_timeout: 5,
        compute_checksums: false,
      )
    end

    def upload_file_to_s3_bucket(path:, body:, content_type:, bucket: bucket_name)
      url = "s3://#{bucket}/#{path}"
      logger.info("#{class_name}: uploading to #{url}")
      obj = Aws::S3::Resource.new(client: s3_client).bucket(bucket).object(path)
      obj.put(body: body, acl: 'private', content_type: content_type)
      logger.debug("#{class_name}: upload completed to #{url}")
      url
    end

    def key(timestamp, issuer)
      formatted_time = timestamp.in_time_zone('UTC').change(min: 0, sec: 0).iso8601
      "fcms-events:#{sanitize(issuer)}:#{sanitize(formatted_time)}"
    end

    def sanitize(key_string)
      key_string.tr(':', '-')
    end
  end
end
