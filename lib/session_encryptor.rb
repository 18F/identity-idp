class SessionEncryptor
  class SensitiveKeyError < StandardError; end
  NEW_CIPHERTEXT_HEADER = 'v2'
  SENSITIVE_KEYS = [
    'first_name', 'middle_name', 'last_name', 'address1', 'address2', 'city', 'state', 'zipcode',
    'zip_code', 'dob', 'phone', 'phone_number', 'ssn', 'prev_address1', 'prev_address2',
    'prev_city', 'prev_state', 'prev_zipcode', 'pii', 'pii_from_doc', 'password', 'personal_key'
  ].to_set.freeze

  SENSITIVE_PATHS = [
    ['warden.user.user.session', 'idv/doc_auth'],
    ['warden.user.user.session', 'idv'],
    ['warden.user.user.session', 'personal_key'],
    ['flash', 'flashes', 'personal_key'],
  ]

  def load(value)
    return LegacySessionEncryptor.new.load(value) if should_use_legacy_encryptor_for_read?(value)

    _v2, ciphertext = value.split(':')
    decrypted = outer_encryptor.decrypt(ciphertext)

    session = JSON.parse(decrypted, quirks_mode: true).with_indifferent_access
    kms_decrypt_sensitive_paths!(session)

    session
  end

  def dump(value)
    return LegacySessionEncryptor.new.dump(value) if should_use_legacy_encryptor_for_write?
    value.deep_stringify_keys!

    kms_encrypt_pii!(value)
    kms_encrypt_sensitive_paths!(value, SENSITIVE_PATHS)
    alert_or_raise_if_contains_sensitive_keys!(value)
    plain = JSON.generate(value, quirks_mode: true)
    NEW_CIPHERTEXT_HEADER + ':' + outer_encryptor.encrypt(plain)
  end

  def kms_encrypt(text)
    Base64.encode64(Encryption::KmsClient.new.encrypt(text, 'context' => 'session-encryption'))
  end

  def kms_decrypt(text)
    Encryption::KmsClient.new.decrypt(
      Base64.decode64(text), 'context' => 'session-encryption'
    )
  end

  def outer_encryptor
    Encryption::Encryptors::AttributeEncryptor.new
  end

  private

  def kms_encrypt_pii!(session)
    return unless session.dig('warden.user.user.session', 'decrypted_pii')
    decrypted_pii = session['warden.user.user.session'].delete('decrypted_pii')
    session['warden.user.user.session']['encrypted_pii'] =
      kms_encrypt(decrypted_pii)
    nil
  end

  def kms_encrypt_sensitive_paths!(session, sensitive_paths)
    sensitive_data = {
    }

    sensitive_paths.each do |path|
      all_but_last_key = path[0..-2]
      last_key = path.last
      value = session.dig(*all_but_last_key)&.delete(last_key)
      if value
        all_but_last_key.reduce(sensitive_data) do |hash, key|
          hash[key] ||= {}

          hash[key]
        end

        if all_but_last_key.blank?
          sensitive_data[last_key] = value
        else
          sensitive_data.dig(*all_but_last_key).store(last_key, value)
        end
      end
    end

    raise 'invalid session' if session['sensitive_data'].present?
    return if sensitive_data.blank?
    session['sensitive_data'] = kms_encrypt(JSON.generate(sensitive_data))
  end

  def kms_decrypt_sensitive_paths!(session)
    sensitive_data = session.delete('sensitive_data')
    return if sensitive_data.blank?

    sensitive_data = JSON.parse(
      kms_decrypt(sensitive_data), quirks_mode: true
    )

    session.deep_merge!(sensitive_data)
  end

  def alert_or_raise_if_contains_sensitive_keys!(hash)
    hash.deep_transform_keys do |key|
      if SENSITIVE_KEYS.include?(key.to_s)
        exception = SensitiveKeyError.new("#{key} unexpectedly appeared in session")
        if IdentityConfig.store.session_encryptor_alert_enabled
          NewRelic::Agent.notice_error(
            exception, custom_params: {
              session_structure: hash.deep_transform_values { |v| nil },
            }
          )
        else
          raise exception
        end
      end
    end
  end

  def should_use_legacy_encryptor_for_read?(value)
    ## Legacy ciphertexts will not include a colon and thus will have no header
    header = value.split(':').first
    header != NEW_CIPHERTEXT_HEADER
  end

  def should_use_legacy_encryptor_for_write?
    !IdentityConfig.store.session_encryptor_v2_enabled
  end
end
