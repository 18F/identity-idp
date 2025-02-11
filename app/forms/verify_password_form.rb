# frozen_string_literal: true

class VerifyPasswordForm
  include ActiveModel::Model

  validates :password, presence: true
  validate :validate_password

  attr_reader :user, :password, :decrypted_pii, :personal_key

  def initialize(user:, password:, decrypted_pii:)
    @user = user
    @password = password
    @decrypted_pii = decrypted_pii
  end

  def submit
    success = valid?

    @personal_key = reencrypt_pii if success

    FormResponse.new(success:, errors:, serialize_error_details_only: true)
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
    profile.clear_password_reset_deactivation_reason
    personal_key
  end

  def profile
    @profile ||= user.password_reset_profile
  end
end
