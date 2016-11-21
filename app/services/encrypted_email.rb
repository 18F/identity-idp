class EncryptedEmail
  def self.build_user_access_key
    env = Figaro.env
    UserAccessKey.new(
      password: env.email_encryption_key,
      salt: env.password_pepper,
      cost: env.email_encryption_cost
    )
  end

  cattr_reader :user_access_key do
    build_user_access_key
  end

  def self.new_from_email(email)
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

  def decrypt
    encryptor = Pii::PasswordEncryptor.new
    encryptor.decrypt(encrypted_email, self.class.user_access_key)
  end
end
