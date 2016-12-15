module KeyRotator
  class EmailEncryption
    def initialize
      self.new_cost = Figaro.env.email_encryption_cost
      self.encryptor = Pii::PasswordEncryptor.new
    end

    def rotate(user)
      ee = EncryptedEmail.new_from_email(user.email, new_email_uak)
      user.update_columns(encrypted_email: ee.encrypted, email_encryption_cost: new_cost)
    end

    private

    attr_accessor :encryptor, :new_cost

    def new_email_uak
      EncryptedEmail.new_user_access_key(cost: new_cost)
    end
  end
end
