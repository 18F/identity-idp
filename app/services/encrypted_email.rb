class EncryptedEmail
  attr_accessor :user_access_key

  def self.new_user_access_key(cost: nil, key: nil)
    env = Figaro.env
    key ||= env.email_encryption_key
    cost ||= env.email_encryption_cost
    UserAccessKey.new(password: key, salt: key, cost: cost)
  end

  def self.new_from_email(email, user_access_key = new_user_access_key)
    encryptor = Pii::PasswordEncryptor.new
    encrypted_email = encryptor.encrypt(email, user_access_key)
    ee = new(encrypted_email, email: email)
    ee.user_access_key = user_access_key
    ee
  end

  def initialize(encrypted_email, email: nil, cost: nil)
    self.encrypted_email = encrypted_email
    self.email = email.present? ? email : decrypt(cost)
  end

  def encrypted
    encrypted_email
  end

  def decrypted
    email
  end

  def fingerprint
    Pii::Fingerprinter.fingerprint(email.downcase)
  end

  def stale?
    user_access_key.salt != current_salt
  end

  private

  attr_accessor :email, :encrypted_email

  def current_salt
    user_access_key.cost + OpenSSL::Digest::SHA256.hexdigest(Figaro.env.email_encryption_key)
  end

  def decrypt(cost)
    encryptor = Pii::PasswordEncryptor.new
    encryption_keys.each do |key|
      email = try_decrypt(encryptor, key, cost) or next
      return email
    end
    raise Pii::EncryptionError, 'unable to decrypt email with any key'
  end

  def try_decrypt(encryptor, key, cost)
    self.user_access_key = self.class.new_user_access_key(cost: cost, key: key)
    encryptor.decrypt(encrypted_email, user_access_key)
  rescue Pii::EncryptionError => _err
    nil
  end

  def encryption_keys
    [Figaro.env.email_encryption_key] + KeyRotator::Utils.old_keys(:email_encryption_key_queue)
  end
end
