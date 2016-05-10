module FormEmailValidator
  extend ActiveSupport::Concern

  included do
    validate :email_is_unique

    validates :email,
              email: {
                mx: true,
                ban_disposable_email: true
              }
  end

  private

  def email_is_unique
    return if email.nil? || (persisted? && email == @user.email)

    errors.add(:email, :taken) if User.exists?(email: email)
  end
end
