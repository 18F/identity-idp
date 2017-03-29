module KeyRotator
  class AttributeEncryption
    def initialize(user)
      @user = user
      self.new_cost = Figaro.env.attribute_cost
      self.encryptor = Pii::PasswordEncryptor.new
    end

    # rubocop:disable Rails/SkipsModelValidations
    def rotate
      user.update_columns(encrypted_attributes)
    end
    # rubocop:enable Rails/SkipsModelValidations

    private

    attr_accessor :encryptor, :new_cost
    attr_reader :user

    def uak
      @_uak ||= EncryptedAttribute.new_user_access_key(cost: new_cost)
    end

    def encrypted_attributes
      User.encryptable_attributes.each_with_object({}) do |attribute, result|
        plain_attribute = user.public_send(attribute)
        next unless plain_attribute

        result[:"encrypted_#{attribute}"] = EncryptedAttribute.new_from_decrypted(
          plain_attribute,
          uak
        ).encrypted
      end
    end
  end
end
