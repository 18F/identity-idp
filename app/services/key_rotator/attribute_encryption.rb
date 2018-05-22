module KeyRotator
  class AttributeEncryption
    def initialize(user)
      @user = user
      @encryptor = Encryption::Encryptors::AttributeEncryptor.new
    end

    # rubocop:disable Rails/SkipsModelValidations
    def rotate
      user.update_columns(encrypted_attributes)
    end
    # rubocop:enable Rails/SkipsModelValidations

    private

    attr_reader :user, :encryptor

    def encrypted_attributes
      User.encryptable_attributes.each_with_object({}) do |attribute, result|
        plain_attribute = user.public_send(attribute)
        next unless plain_attribute

        result[:"encrypted_#{attribute}"] = EncryptedAttribute.new_from_decrypted(
          plain_attribute
        ).encrypted
      end
    end
  end
end
