module PushNotificationsHelper
  def authorization_header(push_to_url, payload)
    web_push(push_to_url, payload)
  end

  def jwt_data(push_to_url, push_data_hash)
    { 'aud': push_to_url,
      'exp': (Time.zone.now + 12.hours).to_i,
      'payload': push_data_hash,
      'sub': 'mailto:partners@login.gov' }
  end

  def web_push(push_to_url, push_data_hash)
    payload = jwt_data(push_to_url, push_data_hash)
    token = JWT.encode(payload, RequestKeyManager.private_key, 'RS256')
    "WebPush #{token}"
  end

  def push_notification_headers(push_url, payload)
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
