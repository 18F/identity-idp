class SessionEncryptor
  class SensitiveKeyError < StandardError; end
  SENSITIVE_KEYS = [
    'first_name', 'middle_name', 'last_name', 'address1', 'address2', 'city', 'state', 'zipcode',
    'zip_code', 'dob', 'phone', 'phone_number', 'ssn', 'prev_address1', 'prev_address2',
    'prev_city', 'prev_state', 'prev_zipcode', 'pii', 'pii_from_doc', 'password', 'personal_key'
  ]

  def load(value)
    return LegacySessionEncryptor.new.load(value) if should_use_legacy_encryptor_for_read?(value)

    _v2, ciphertext = value.split(':')
    decrypted = outer_encryptor.decrypt(ciphertext)

    session = JSON.parse(decrypted, quirks_mode: true).with_indifferent_access
    kms_decrypt_doc_auth_pii!(session)
    kms_decrypt_idv_pii!(session)

    session
  end

  def dump(value)
    return LegacySessionEncryptor.new.dump(value) if should_use_legacy_encryptor_for_write?
    value.deep_stringify_keys!

    kms_encrypt_pii!(value)
    kms_encrypt_doc_auth_pii!(value)
    kms_encrypt_idv_pii!(value)
    alert_or_raise_if_contains_sensitive_keys!(value)
    plain = JSON.generate(value, quirks_mode: true)
    'v2:' + outer_encryptor.encrypt(plain)
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
      kms_encrypt(JSON.generate(decrypted_pii, quirks_mode: true))
    nil
  end

  def kms_encrypt_doc_auth_pii!(session)
    return unless session.dig('warden.user.user.session', 'idv/doc_auth')
    doc_auth_pii = session.dig('warden.user.user.session').delete('idv/doc_auth')
    session['warden.user.user.session']['encrypted_idv/doc_auth'] =
      kms_encrypt(JSON.generate(doc_auth_pii, quirks_mode: true))
    nil
  end

  def kms_decrypt_doc_auth_pii!(session)
    return unless session.dig('warden.user.user.session', 'encrypted_idv/doc_auth')
    doc_auth_pii = session['warden.user.user.session'].delete('encrypted_idv/doc_auth')
    session['warden.user.user.session']['idv/doc_auth'] = JSON.parse(
      kms_decrypt(doc_auth_pii), quirks_mode: true
    )
    nil
  end

  def kms_encrypt_idv_pii!(session)
    return unless session.dig('warden.user.user.session', 'idv')
    idv_pii = session.dig('warden.user.user.session').delete('idv')
    session['warden.user.user.session']['encrypted_idv'] =
      kms_encrypt(JSON.generate(idv_pii, quirks_mode: true))
    nil
  end

  def kms_decrypt_idv_pii!(session)
    return unless session.dig('warden.user.user.session', 'encrypted_idv')
    idv_pii = session['warden.user.user.session'].delete('encrypted_idv')
    session['warden.user.user.session']['idv'] = JSON.parse(kms_decrypt(idv_pii), quirks_mode: true)
    nil
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
    header != 'v2'
  end

  def should_use_legacy_encryptor_for_write?
    !IdentityConfig.store.session_encryptor_v2_enabled
  end
end
