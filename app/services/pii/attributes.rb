module Pii
  Attributes = Struct.new(
    :first_name, :middle_name, :last_name,
    :address1, :address2, :city, :state, :zipcode,
    :ssn, :dob, :phone
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
      attrs = new
      return attrs unless pii_json.present?
      pii = JSON.parse(pii_json, symbolize_names: true)
      pii.each_key { |attr| attrs[attr] = pii[attr] }
      attrs
    end

    def encrypted(user_access_key)
      encryptor = Pii::PasswordEncryptor.new
      encryptor.encrypt(to_json, user_access_key)
    end
  end
end
