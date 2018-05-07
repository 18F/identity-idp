# In order to perform scrypt calculation of password in a single
# place for both password and PII encryption, we override
# a few methods to build the encrypted_password via UserAccessKey
#
module UserAccessKeyOverrides
  extend ActiveSupport::Concern

  attr_accessor :user_access_key

  def password_digest(password)
    user_access_key = Encryption::UserAccessKey.new(
      password: password,
      salt: authenticatable_salt,
      cost: password_cost
    ).build
    self.encryption_key ||= user_access_key.encryption_key
    self.password_cost ||= user_access_key.cost
    user_access_key.encrypted_password
  end

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
    self.user_access_key = Encryption::UserAccessKey.new(
      password: password,
      salt: authenticatable_salt,
      cost: password_cost
    ).unlock(encryption_key)
  end

  def password=(new_password)
    if new_password.present?
      self.password_salt = Devise.friendly_token[0, 20]
      self.encryption_key = nil
      self.password_cost = nil
    end
    super
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
end
