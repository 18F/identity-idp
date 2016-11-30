class EncryptedEmail
  attr_reader :user_access_key

  def self.new_user_access_key
    env = Figaro.env
    UserAccessKey.new(
      password: env.email_encryption_key,
      salt: env.password_pepper,
      cost: env.email_encryption_cost
    )
  end

  def self.new_from_email(email, user_access_key = new_user_access_key)
    encryptor = Pii::PasswordEncryptor.new
    encrypted_email = encryptor.encrypt(email, user_access_key)
    new(encrypted_email, email)
  end

  def initialize(encrypted_email, email = nil)
    self.encrypted_email = encrypted_email
    self.email = email.present? ? email : decrypt
  end

  def encrypted
    encrypted_email
  end

  def decrypted
    email
  end

  def fingerprint
    Pii::Fingerprinter.fingerprint(email)
  end

  private

  attr_accessor :email, :encrypted_email
  attr_writer :user_access_key

  def decrypt
    encryptor = Pii::PasswordEncryptor.new
    self.user_access_key = self.class.new_user_access_key
    encryptor.decrypt(encrypted_email, user_access_key)
  end
end
