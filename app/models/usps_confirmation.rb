class UspsConfirmation < ApplicationRecord
  # Store the pii as encrypted json
  def entry=(entry_hash)
    self[:entry] = encryptor.encrypt(entry_hash.to_json)
  end

  # Read the pii as a decrypted hash
  def entry
    JSON.parse(encryptor.decrypt(self[:entry]), symbolize_names: true)
  end

  private

  def encryptor
    # This currently uses the SessionEncryptor, which is meant to be used to
    # encrypt the session. When this code is changed to integrate a new mail
    # vendor we should create a purpose built encryptor for that vendor
    Encryption::Encryptors::SessionEncryptor.new
  end
end
