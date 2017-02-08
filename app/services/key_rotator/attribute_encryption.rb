module KeyRotator
  class AttributeEncryption
    def initialize(user)
      @user = user
      self.new_cost = Figaro.env.attribute_cost
      self.encryptor = Pii::PasswordEncryptor.new
    end

    def rotate
      user.update_columns(encrypted_attributes)
    end

    private

    attr_accessor :encryptor, :new_cost
    attr_reader :user

    def uak
      @_uak ||= EncryptedAttribute.new_user_access_key(cost: new_cost)
    end

    def encrypted_attributes
      User.attribute_names.grep(/^encrypted_/).each_with_object({}) do |attribute, result|
        plain_attribute_name = attribute.gsub(/^encrypted_/, '')
        plain_attribute = user.public_send(plain_attribute_name)
        next unless plain_attribute

        result[attribute] = EncryptedAttribute.new_from_decrypted(
          plain_attribute,
          uak
        ).encrypted
      end
    end
  end
end
