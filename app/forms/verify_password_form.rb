class VerifyPasswordForm
  include ActiveModel::Model

  validates :password, presence: true
  validate :validate_password

  attr_reader :user, :password, :decrypted_pii

  def initialize(user:, password:, decrypted_pii:)
    @user = user
    @password = password
    @decrypted_pii = decrypted_pii
  end

  def submit
    success = valid?
    extra = {}

    extra[:personal_key] = reencrypt_pii if success

    FormResponse.new(success: success, errors: errors, extra: extra)
  end

  private

  def validate_password
    return if valid_password?
    errors.add :password, :password_incorrect, type: :password_incorrect
  end

  def valid_password?
    user.valid_password?(password)
  end

  def reencrypt_pii
    personal_key = profile.encrypt_pii(decrypted_pii, password)
    profile.activate_after_password_reset
    personal_key
  end

  def profile
    @profile ||= user.password_reset_profile
  end
end
