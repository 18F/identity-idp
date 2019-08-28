module PushNotificationsHelper
  def stub_push_notification_request(sp_push_notification_endpoint:, topic:, payload:)
    stub_request(:post, sp_push_notification_endpoint).with do |request|
      expect(request.body).to eq('')

      headers = request.headers
      expect(headers['Topic']).to eq(topic)
      expect(headers['Content-Type']).to eq('application/json')

      parsed_jwt = parse_jwt_from_auth_header(headers['Authorization'])
      expect(parsed_jwt['iss']).to eq('http://www.example.com/')
      expect(parsed_jwt['aud']).to eq(sp_push_notification_endpoint)
      expected_expiration = 12.hours.from_now
      expect(parsed_jwt['exp']).to be_within(2).of(expected_expiration.to_i)
      expect(parsed_jwt['events'][PushNotification::AccountDelete::EVENT_TYPE_URI]).to eq(payload)
    end.to_return(body: '')
  end

  def parse_jwt_from_auth_header(auth_header)
    jwt = auth_header.match(/WebPush (.*)/)[1]
    JWT.decode(jwt, RequestKeyManager.public_key, true, algorithm: 'RS256').first
  end
end
