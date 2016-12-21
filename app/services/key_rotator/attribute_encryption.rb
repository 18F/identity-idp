module KeyRotator
  class AttributeEncryption
    def initialize
      self.new_cost = Figaro.env.attribute_cost
      self.encryptor = Pii::PasswordEncryptor.new
    end

    def rotate(user)
      user.update_columns(build_rotated_columns(user))
    end

    private

    attr_accessor :encryptor, :new_cost

    def uak
      @_uak ||= EncryptedAttribute.new_user_access_key(cost: new_cost)
    end

    def build_rotated_columns(user)
      email = EncryptedAttribute.new_from_decrypted(user.email, uak)
      to_update = { encrypted_email: email.encrypted, attribute_cost: new_cost }
      plain_phone = user.phone
      if plain_phone.present?
        to_update[:encrypted_phone] = EncryptedAttribute.new_from_decrypted(
          plain_phone,
          uak
        ).encrypted
      end
      to_update
    end
  end
end
