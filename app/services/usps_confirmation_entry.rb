UspsConfirmationEntry = Struct.new(
  :address1,
  :address2,
  :city,
  :first_name,
  :last_name,
  :otp,
  :state,
  :zipcode,
  :issuer
) do
  def self.user_access_key
    SessionEncryptor.new.duped_user_access_key
  end

  def self.encryptor
    Pii::PasswordEncryptor.new
  end

  def self.new_from_hash(hash)
    attrs = new
    hash.each { |key, val| attrs[key] = val }
    attrs
  end

  def self.new_from_encrypted(encrypted)
    decrypted = encryptor.decrypt(encrypted, user_access_key)
    new_from_json(decrypted)
  end

  def self.new_from_json(pii_json)
    return new if pii_json.blank?
    pii = JSON.parse(pii_json, symbolize_names: true)
    new_from_hash(pii)
  end

  def encrypted
    klass = self.class
    klass.encryptor.encrypt(to_json, klass.user_access_key)
  end
end
