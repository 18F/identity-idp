module EncryptableAttribute
  extend ActiveSupport::Concern

  module ClassMethods
    cattr_accessor :encryptable_attributes do
      []
    end

    private

    def encrypted_attribute_getter(name)
      class_eval <<-METHODS, __FILE__, __LINE__ + 1
        def #{name}
          get_encrypted_attribute(name: :"#{name}")
        end
      METHODS
    end

    def encrypted_attribute_stale_predicate(name)
      class_eval <<-METHODS, __FILE__, __LINE__ + 1
        def stale_encrypted_#{name}?
          return false unless self.public_send(:"#{name}").present?
          encrypted_attributes[:"#{name}"].stale?
        end
      METHODS
    end

    def encrypted_attribute_setter(name)
      class_eval <<-METHODS, __FILE__, __LINE__ + 1
        def #{name}=(attribute)
          set_encrypted_attribute(name: :"#{name}", value: attribute)
        end
      METHODS
    end

    def encrypted_attribute(name:)
      encryptable_attributes << name

      encrypted_attribute_getter(name)
      encrypted_attribute_stale_predicate(name)
      encrypted_attribute_setter(name)
    end

    def encrypted_attribute_without_setter(name:)
      encryptable_attributes << name

      encrypted_attribute_getter(name)
      encrypted_attribute_stale_predicate(name)
    end
  end

  private

  def encrypted_attributes
    @_encrypted_attributes ||= {}
  end

  def get_encrypted_attribute(name:)
    getter = encrypted_attribute_name(name)
    encrypted_string = self[getter]
    return encrypted_string if encrypted_string.blank?
    encrypted_attribute = encrypted_attributes[name]
    return encrypted_attribute.decrypted if encrypted_attribute.present?
    build_encrypted_attribute(name, encrypted_string).decrypted
  end

  def build_encrypted_attribute(name, encrypted_string)
    encrypted_attribute = EncryptedAttribute.new(encrypted_string)
    encrypted_attributes[name] = encrypted_attribute
  end

  def set_encrypted_attribute(name:, value:)
    setter = encrypted_attribute_name(name)
    new_value = if value.present?
                  build_encrypted_attribute_from_plain(name, value).encrypted
                else
                  value
                end
    self[setter] = new_value
  end

  def build_encrypted_attribute_from_plain(name, plain_value)
    encrypted_attributes[name] = EncryptedAttribute.new_from_decrypted(plain_value.downcase.strip)
  end

  def encrypted_attribute_name(name)
    "encrypted_#{name}".to_sym
  end
end
