class VerifyPersonalKeyForm
  include ActiveModel::Model
  include PersonalKeyValidator

  validates :personal_key, presence: true
  validate :validate_personal_key

  attr_accessor :personal_key
  attr_reader :user

  def initialize(user:, personal_key:)
    @user = user
    @personal_key = normalize_personal_key(personal_key)
  end

  def submit
    extra = {}
    success = valid?

    if success
      extra[:decrypted_pii] = decrypted_pii_json
    else
      reset_sensitive_fields
    end

    FormResponse.new(success: valid?, errors: errors, extra: extra)
  end

  private

  def decrypted_pii_json
    decrypted_pii.to_json
  end

  def password_reset_profile
    user.decorate.password_reset_profile
  end

  def decrypted_pii
    @_pii ||= password_reset_profile.recover_pii(personal_key)
  end

  def validate_personal_key
    return check_personal_key if personal_key_decrypts?
    errors.add :personal_key, :personal_key_incorrect
  end

  def reset_sensitive_fields
    self.personal_key = nil
  end

  def personal_key_decrypts?
    decrypted_pii.present?
  rescue Encryption::EncryptionError => _err
    false
  end
end
