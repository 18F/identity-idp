class CreateOmniauthUser
  include ActiveModel::Model
  include FormEmailValidator

  delegate :email, to: :user

  def user
    @user ||= User.new
  end

  def initialize(email)
    user.email = email
  end

  def persisted?
    true
  end

  def perform
    return unless valid?

    ee = EncryptedEmail.new_from_email(email)
    User.find_or_create_by(email_fingerprint: ee.fingerprint) do |user|
      user.update(confirmed_at: Time.current, encrypted_email: ee.encrypted)
    end
  end
end
