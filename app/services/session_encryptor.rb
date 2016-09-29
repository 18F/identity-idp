class SessionEncryptor
  def self.load(value)
    decrypted = encryptor.decrypt_with_key(value)
    Marshal.load(::Base64.decode64(decrypted))
  end

  def self.dump(value)
    plain = ::Base64.encode64(Marshal.dump(value))
    encryptor.encrypt_with_key(plain)
  end

  def self.encryptor
    Pii::Encryptor.new
  end
end
