module EncryptableAttribute
  extend ActiveSupport::Concern

  attr_accessor :attribute_user_access_key

  class_methods do
    cattr_accessor :encryptable_attributes do
      []
    end

    # rubocop:disable MethodLength
    def encrypted_attribute(name:, default:, setter: true)
      self.encryptable_attributes << name

      class_eval <<-METHODS, __FILE__, __LINE__ + 1
        def #{name}
          get_encrypted_attribute(name: :"#{name}", default: #{default.inspect})
        end

        def stale_encrypted_#{name}?
          return false unless self.public_send(:"#{name}").present?
          encrypted_attributes[:"#{name}"].stale?
        end
      METHODS

      return unless setter

      class_eval <<-METHODS, __FILE__, __LINE__ + 1
        def #{name}=(attribute)
          set_encrypted_attribute(name: :"#{name}", value: attribute, default: #{default.inspect})
        end
      METHODS
    end
    # rubocop:enable MethodLength
  end

  private

  def encrypted_attributes
    @_encrypted_attributes ||= {}
  end

  def get_encrypted_attribute(name:, default:)
    getter = encrypted_attribute_name(name)
    encrypted_string = self[getter]
    return default unless encrypted_string.present?
    encrypted_attribute = encrypted_attributes[name]
    return encrypted_attribute.decrypted if encrypted_attribute.present?
    build_encrypted_attribute(name, encrypted_string).decrypted
  end

  def build_encrypted_attribute(name, encrypted_string)
    encrypted_attribute = EncryptedAttribute.new(
      encrypted_string,
      cost: attribute_cost,
      user_access_key: attribute_user_access_key
    )
    self.attribute_user_access_key ||= encrypted_attribute.user_access_key
    encrypted_attributes[name] = encrypted_attribute
  end

  def set_encrypted_attribute(name:, value:, default:)
    setter = encrypted_attribute_name(name)
    new_value = default
    if value.present?
      new_value = build_encrypted_attribute_from_plain(name, value).encrypted
    end
    self[setter] = new_value
  end

  def build_encrypted_attribute_from_plain(name, plain_value)
    self.attribute_user_access_key ||= new_attribute_user_access_key
    encrypted_attributes[name] = EncryptedAttribute.new_from_decrypted(
      plain_value.downcase.strip,
      attribute_user_access_key
    )
  end

  def encrypted_attribute_name(name)
    "encrypted_#{name}".to_sym
  end

  def new_attribute_user_access_key
    EncryptedAttribute.new_user_access_key(cost: attribute_cost)
  end
end
