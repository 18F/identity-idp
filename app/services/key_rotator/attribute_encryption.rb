module KeyRotator
  class AttributeEncryption
    def initialize(model)
      @model = model
      @encryptor = Encryption::Encryptors::AttributeEncryptor.new
    end

    # rubocop:disable Rails/SkipsModelValidations
    def rotate
      model.update_columns(encrypted_attributes)
    end
    # rubocop:enable Rails/SkipsModelValidations

    private

    attr_reader :model, :encryptor

    def encrypted_attributes
      model.class.encryptable_attributes.each_with_object({}) do |attribute, result|
        plain_attribute = model.public_send(attribute)
        next unless plain_attribute

        result[:"encrypted_#{attribute}"] = EncryptedAttribute.new_from_decrypted(
          plain_attribute,
        ).encrypted
      end
    end
  end
end
