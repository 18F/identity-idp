class SessionEncryptor
  def self.load(value)
    decrypted = encryptor.decrypt(value)
    Marshal.load(::Base64.decode64(decrypted))
  end

  def self.dump(value)
    plain = ::Base64.encode64(Marshal.dump(value))
    encryptor.encrypt(plain)
  end

  def self.encryptor
    Pii::Encryptor.new
  end
end
