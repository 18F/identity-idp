# frozen_string_literal: true

class FraudOpsRedisClientWrapper
  def initialize
    @redis_client = FraudOpsRedisClient.new
  end

  def write_event(event_key:, jwe:, timestamp:, issuer:)
    event_data = decrypt_jwe(jwe)
    return unless event_data

    encrypted_event = encrypt_event_data(event_data)

    @redis_client.write_event(
      event_key: event_key,
      encrypted_data: encrypted_event,
      timestamp: timestamp,
    )
  end

  private

  def decrypt_jwe(jwe)
    begin
      JSON.parse(jwe)
    rescue JSON::ParserError => e
      Rails.logger.error("FraudOpsTracker: Failed to parse payload as JSON: #{e.message}")
      nil
    end
  end

  def encrypt_event_data(event_data)
    return event_data.to_json unless encryption_key.present?

    cipher = OpenSSL::Cipher.new('AES-256-GCM')
    cipher.encrypt
    cipher.key = Base64.decode64(encryption_key)
    iv = cipher.random_iv

    encrypted_data = cipher.update(event_data.to_json) + cipher.final
    auth_tag = cipher.auth_tag

    Base64.encode64(
      {
        iv: Base64.encode64(iv),
        auth_tag: Base64.encode64(auth_tag),
        data: Base64.encode64(encrypted_data),
      }.to_json,
    )
  end

  def encryption_key
    IdentityConfig.store.attribute_encryption_key
  end
end
