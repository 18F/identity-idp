module PushNotificationsHelper
  def authorization_header(push_to_url, payload)
    web_push(push_to_url, payload)
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

  def signature(payload)
    JWT.encode({ iat: Time.zone.now.to_i, payload: payload },
               RequestKeyManager.private_key,
               'RS256')
  end

  def web_push(push_to_url, payload)
    "WebPush #{jwt_info}.#{jwt_data(push_to_url)}.#{signature(payload)}"
  end

  def headers(push_url, payload)
    {
      'Authorization' => authorization_header(push_url, payload),
      'Content-Length' => '0',
      'Content-Type' => 'application/json',
      'Expect' => '',
      'Topic' => 'account_delete',
      'User-Agent' => 'Faraday v0.15.4',
    }
  end
end
