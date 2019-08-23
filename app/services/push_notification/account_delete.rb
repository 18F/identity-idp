module PushNotification
  class AccountDelete
    EVENT_TYPE_URI = 'https://schemas.openid.net/secevent/risc/event-type/account-purged'.freeze

    def call(user_id)
      send_updates_to_subscribers(user_id)
    end

    private

    def send_updates_to_subscribers(user_id)
      agency_id_to_uuid_hash = agency_id_to_uuid(user_id)
      agency_ids = agency_id_to_uuid_hash.keys
      push_notification_sps.each do |sp|
        agency_id = sp.agency_id
        next unless agency_ids.index(agency_id)
        push_notify(sp.issuer,
                    sp.push_notification_url,
                    agency_id_to_uuid_hash[agency_id],
                    agency_id)
      end
    end

    def agency_id_to_uuid(user_id)
      hash = {}
      AgencyIdentity.where(user_id: user_id).each do |row|
        hash[row.agency_id] = row.uuid
      end
      hash
    end

    def push_notification_sps
      ServiceProvider.all.where("push_notification_url is NOT NULL and push_notification_url!=''")
    end

    def push_notify(issuer, push_notification_url, uuid, agency_id)
      payload = build_payload(issuer, push_notification_url, uuid)
      result = post_to_push_notification_url(push_notification_url, payload)
      unless result.success?
        raise(PushNotification::PushNotificationError,
              "status=#{result.status}")
      end
    rescue Faraday::TimeoutError,
           Faraday::ConnectionFailed,
           PushNotification::PushNotificationError => exception
      handle_failure(exception, agency_id, uuid)
    end

    # Payload format per
    # https://openid.net/specs/openid-risc-event-types-1_0-ID1.html#account-purged
    # rubocop:disable Metrics/MethodLength
    def build_payload(issuer, push_notification_url, uuid)
      iat = Time.zone.now.to_i
      {
        iss: Rails.application.routes.url_helpers.root_url,
        iat: iat,
        exp: iat + 12.hours.to_i,
        jti: jti(iat),
        aud: push_notification_url,
        events: {
          EVENT_TYPE_URI => {
            subject: {
              subject_type: 'iss-sub',
              iss: issuer,
              sub: uuid,
            },
          },
        },
      }
    end
    # rubocop:enable Metrics/MethodLength

    # :reek:FeatureEnvy
    def post_to_push_notification_url(push_to_url, payload)
      adapter = faraday_adapter(push_to_url)
      adapter.post do |request|
        headers_hash = request.headers
        headers_hash['topic'] = 'account_delete'
        headers_hash['content-type'] = 'application/json'
        headers_hash['authorization'] = web_push(payload)
      end
    end

    def web_push(payload)
      token = JSON::JWT.new(payload)
      signed_token = token.sign(RequestKeyManager.private_key)
      "WebPush #{signed_token}"
    end

    def jti(iat)
      jti_raw = [RequestKeyManager.public_key, iat].join(':').to_s
      Digest::MD5.hexdigest(jti_raw)
    end

    def handle_failure(exception, agency_id, uuid)
      Rails.logger.error "Push message failed #{exception.message}"
      PushAccountDelete.create(created_at: Time.zone.now, agency_id: agency_id, uuid: uuid)
      NewRelic::Agent.notice_error(exception)
    end

    def faraday_adapter(url)
      Faraday.new(url: url) do |faraday|
        faraday.adapter :typhoeus
      end
    end
  end
end
