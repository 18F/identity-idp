class ReactivateProfileForm
  include ActiveModel::Model

  validates :recovery_code, :password, presence: true
  validate :validate_password_reset_profile
  validate :validate_password
  validate :validate_recovery_code

  attr_accessor :recovery_code, :password
  attr_reader :user

  def initialize(user, attrs = {})
    options = { recovery_code: [] }.merge(attrs)
    @user = user
    super options

    @recovery_code = recovery_code.join(' ')
  end

  def submit(flash)
    if valid?
      flash[:recovery_code] = reencrypt_pii
      true
    else
      clear_fields
      false
    end
  end

  protected

  def password_reset_profile
    @_password_reset_profile ||= user.password_reset_profile
  end

  def user_access_key
    @_uak ||= user.unlock_user_access_key(password)
  end

  def decrypted_pii
    @_pii ||= password_reset_profile.recover_pii(recovery_code)
  end

  def reencrypt_pii
    recovery_code = password_reset_profile.encrypt_pii(user_access_key, decrypted_pii)
    password_reset_profile.deactivation_reason = nil
    password_reset_profile.save!
    recovery_code
  end

  def validate_password_reset_profile
    errors.add :base, :no_password_reset_profile unless password_reset_profile
  end

  def validate_password
    return if password.blank? || valid_password?
    errors.add :password, :password_incorrect
  end

  def validate_recovery_code
    return if recovery_code.blank? || (valid_recovery_code? && recovery_code_decrypts?)
    errors.add :recovery_code, :recovery_code_incorrect
  end

  # Reset sensitive fields so they don't get sent back to the browser
  def clear_fields
    self.password = nil
  end

  def valid_password?
    user.valid_password?(password)
  end

  def recovery_code_decrypts?
    decrypted_pii.present?
  rescue Pii::EncryptionError => _err
    false
  end

  def valid_recovery_code?
    RecoveryCodeGenerator.new(user).verify(recovery_code)
  end
end
