class SessionEncryptor
  def load(value)
    decrypted = nil
    begin
      decrypted = encryptor.decrypt(value)
    rescue Encryption::EncryptionError => e
      decrypted = old_encryptor.decrypt(value)
    end

    JSON.parse(decrypted, quirks_mode: true).with_indifferent_access
  end

  def dump(value)
    plain = JSON.generate(value, quirks_mode: true)
    if IdentityConfig.store.write_new_session_format
      encryptor.encrypt(plain)
    else
      old_encryptor.encrypt(plain)
    end
  end

  private

  def old_encryptor
    Encryption::Encryptors::SessionEncryptor.new
  end

  def encryptor
    Encryption::Encryptors::SmallSessionEncryptor.new
  end
end
