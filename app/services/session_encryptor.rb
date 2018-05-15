class SessionEncryptor
  def load(value)
    decrypted = encryptor.decrypt(value)

    JSON.parse(decrypted, quirks_mode: true).with_indifferent_access
  end

  def dump(value)
    plain = JSON.generate(value, quirks_mode: true)
    encryptor.encrypt(plain)
  end

  private

  def encryptor
    Encryption::Encryptors::SessionEncryptor.new
  end
end
