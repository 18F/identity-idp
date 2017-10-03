class SessionEncryptor
  def cipher
    @cipher ||= Gibberish::AES.new(Figaro.env.session_encryption_key)
  end

  def load(value)
    decrypted = cipher.decrypt(value)
    JSON.parse(decrypted, quirks_mode: true).with_indifferent_access
  end

  def dump(value)
    plain = JSON.generate(value, quirks_mode: true)
    cipher.encrypt(plain)
  end

  private

  def encryptor
    Pii::PasswordEncryptor.new
  end
end
