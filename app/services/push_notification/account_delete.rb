module PushNotification
  class AccountDelete
    def call(user_id)
      send_updates_to_subscribers(user_id)
    end

    private

    def push_notify(push_to_url, uuid, agency_id)
      payload = { uuid: uuid }
      result = post_to_push_notification_url(push_to_url, payload)
      handle_failure("status=#{result.status}", agency_id, uuid) unless result.success?
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => exception
      handle_failure(exception.message, agency_id, uuid)
    end

    def handle_failure(message, agency_id, uuid)
      Rails.logger.error "Push message failed #{message}"
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

    def web_push(push_to_url, push_data_hash)
      payload = jwt_data(push_to_url, push_data_hash)
      token = JWT.encode(payload, RequestKeyManager.private_key, 'RS256')
      "WebPush #{token}"
    end

    def jwt_data(push_to_url, push_data_hash)
      { 'aud': push_to_url,
        'exp': (Time.zone.now + 12.hours).to_i,
        'payload': push_data_hash,
        'sub': 'mailto:partners@login.gov' }
    end

    def push_notification_sps
      ServiceProvider.all.where("push_notification_url is NOT NULL and push_notification_url!=''")
    end

    def send_updates_to_subscribers(user_id)
      agency_id_to_uuid_hash = agency_id_to_uuid(user_id)
      agency_ids = agency_id_to_uuid_hash.keys
      push_notification_sps.each do |sp|
        agency_id = sp.agency_id
        next unless agency_ids.index(agency_id)
        push_notify(sp.push_notification_url, agency_id_to_uuid_hash[agency_id], agency_id)
      end
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
