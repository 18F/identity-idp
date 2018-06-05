# In order to perform scrypt calculation of password in a single
# place for both password and PII encryption, we override
# a few methods to build the encrypted_password via UserAccessKey
#
module UserAccessKeyOverrides
  extend ActiveSupport::Concern

  attr_accessor :user_access_key

  def valid_password?(password)
    return false if encrypted_password.blank?
    begin
      unlock_user_access_key(password)
    rescue Pii::EncryptionError => err
      log_error(err)
      return false
    end
    Devise.secure_compare(encrypted_password, user_access_key.encrypted_password)
  end

  def unlock_user_access_key(password)
    self.user_access_key = build_user_access_key(password).unlock(encryption_key)
  end

  def password=(new_password)
    @password = new_password
    encrypt_password(@password) if @password.present?
  end

  def authenticatable_salt
    password_salt
  end

  private

  def log_error(err)
    metadata = {
      event: 'Pii::EncryptionError when validating password',
      error: err.to_s,
      uuid: uuid,
      timestamp: Time.zone.now,
    }
    Rails.logger.info(metadata.to_json)
  end

  def encrypt_password(new_password)
    self.password_salt = Devise.friendly_token[0, 20]

    user_access_key = build_user_access_key(new_password, cost: nil).build

    self.encryption_key = user_access_key.encryption_key
    self.password_cost = user_access_key.cost
    self.encrypted_password = user_access_key.encrypted_password
    self.encrypted_password_digest = build_encrypted_password_digest
  end

  def build_user_access_key(password, salt: authenticatable_salt, cost: password_cost)
    Encryption::UserAccessKey.new(
      password: password,
      salt: salt,
      cost: cost
    )
  end

  def build_encrypted_password_digest
    {
      encryption_key: encryption_key,
      encrypted_password: encrypted_password,
      password_cost: password_cost,
      password_salt: password_salt,
    }.to_json
  end
end
