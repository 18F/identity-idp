module PushNotification
  class AccountDelete
    def call(user_id)
      send_updates_to_subscribers(user_id)
    end

    private

    def push_notify(push_to_url, uuid, agency_id)
      payload = { uuid: uuid }
      post_to_push_notification_url(push_to_url, payload)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => exception
      Rails.logger.error "Push message failed #{exception.message}"
      PushAccountDelete.create(created_at: Time.zone.now, agency_id: agency_id, uuid: uuid)
    end

    # :reek:FeatureEnvy
    def post_to_push_notification_url(push_to_url, payload)
      adapter = faraday_adapter(push_to_url)
      adapter.post do |request|
        headers_hash = request.headers
        headers_hash['topic'] = 'account_delete'
        headers_hash['content-type'] = 'application/json'
        headers_hash['authorization'] = web_push(push_to_url, payload)
      end
    end

    def signature(payload)
      JWT.encode({ iat: Time.zone.now.to_i, payload: payload },
                 RequestKeyManager.private_key,
                 'RS256')
    end

    def web_push(push_to_url, payload)
      "WebPush #{jwt_info}.#{jwt_data(push_to_url)}.#{signature(payload)}"
    end

    def jwt_data(push_to_url)
      Base64.strict_encode64({ 'aud': push_to_url,
                               'exp': (Time.zone.now + 12.hours).to_i,
                               'sub': 'mailto:partners@login.gov' }.to_json)
    end

    def jwt_info
      Base64.strict_encode64({ 'typ': 'JWT',
                               'alg': 'RS256' }.to_json)
    end

    def push_notification_sps
      ServiceProvider.all.where("push_notification_url is NOT NULL and push_notification_url!=''")
    end

    def send_updates_to_subscribers(user_id)
      agency_id_to_uuid_hash = agency_id_to_uuid(user_id)
      agency_ids = agency_id_to_uuid_hash.keys
      push_notification_sps.each do |sp|
        send_update_to_subscriber(sp.agency_id,
                                  sp.push_notification_url,
                                  agency_ids,
                                  agency_id_to_uuid_hash)
      end
    end

    def send_update_to_subscriber(agency_id, push_url, agency_ids, agency_id_to_uuid_hash)
      return unless agency_ids.index(agency_id)
      uuid = agency_id_to_uuid_hash[agency_id]
      push_notify(push_url, uuid, agency_id)
    end

    def agency_id_to_uuid(user_id)
      hash = {}
      AgencyIdentity.where(user_id: user_id).each do |row|
        hash[row.agency_id] = row.uuid
      end
      hash
    end

    def faraday_adapter(url)
      Faraday.new(url: url) do |faraday|
        faraday.adapter :typhoeus
      end
    end
  end
end
