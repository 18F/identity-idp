module Pii
  DEPRECATED_PII_ATTRIBUTES = [
    :otp, # https://github.com/18F/identity-idp/pull/1661
  ].freeze

  Attributes = Struct.new(
    :first_name, :middle_name, :last_name,
    :address1, :address2, :city, :state, :zipcode,
    :ssn, :dob, :phone,
    :prev_address1, :prev_address2, :prev_city, :prev_state, :prev_zipcode,
    *DEPRECATED_PII_ATTRIBUTES
  ) do
    def self.new_from_hash(hash)
      attrs = new
      hash.each { |key, val| attrs[key] = val }
      attrs
    end

    def self.new_from_encrypted(encrypted, user_access_key)
      encryptor = Pii::PasswordEncryptor.new
      decrypted = encryptor.decrypt(encrypted, user_access_key)
      new_from_json(decrypted)
    end

    def self.new_from_json(pii_json)
      return new if pii_json.blank?
      pii = JSON.parse(pii_json, symbolize_names: true)
      new_from_hash(pii)
    end

    def initialize(*args)
      super
      assign_all_members
    end

    def encrypted(user_access_key)
      encryptor = Pii::PasswordEncryptor.new
      encryptor.encrypt(to_json, user_access_key)
    end

    def eql?(other)
      to_json == other.to_json
    end

    def ==(other)
      eql?(other)
    end

    def []=(key, value)
      if value.is_a?(Hash)
        super(key, Pii::Attribute.new(value))
      elsif value.is_a?(Pii::Attribute)
        super(key, value)
      else
        super(key, Pii::Attribute.new(raw: value))
      end
    end

    private

    def assign_all_members
      self.class.members.each do |member|
        self[member] = self[member]
      end
    end
  end
end
