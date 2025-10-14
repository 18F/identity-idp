module PushNotificationsHelper
  def stub_push_notification_request(service_provider:, event_type:, payload:)
    stub_request(:post, service_provider.push_notification_url).with do |request|
      parsed_jwt, _jwt_headers = JWT.decode(
        request.body,
        Rails.application.config.oidc_public_key,
        true,
        algorithm: 'RS256',
      )

      expect(request.headers['Content-Type']).to eq('application/secevent+jwt')

      expect(parsed_jwt['iss']).to eq('http://www.example.com/')
      expect(parsed_jwt['aud']).to eq(service_provider.issuer)
      expected_expiration = 12.hours.from_now
      expect(parsed_jwt['exp']).to be_within(2).of(expected_expiration.to_i)
      expect(parsed_jwt['events'][event_type]).to eq(payload)
    end.to_return(body: '')
  end
end
