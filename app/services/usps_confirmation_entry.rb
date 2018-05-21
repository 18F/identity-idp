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
  def self.encryptor
    # This currently uses the SessionEncryptor, which is meant to be used to
    # encrypt the session. When this code is changed to integrate a new mail
    # vendor we should create a purpose built encryptor for that vendor
    Encryption::Encryptors::SessionEncryptor.new
  end

  def self.new_from_hash(hash)
    attrs = new
    hash.each { |key, val| attrs[key] = val }
    attrs
  end

  def self.new_from_encrypted(encrypted)
    decrypted = encryptor.decrypt(encrypted)
    new_from_json(decrypted)
  end

  def self.new_from_json(pii_json)
    return new if pii_json.blank?
    pii = JSON.parse(pii_json, symbolize_names: true)
    new_from_hash(pii)
  end

  def encrypted
    klass = self.class
    klass.encryptor.encrypt(to_json)
  end
end
