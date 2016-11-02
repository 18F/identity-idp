module FormEmailValidator
  extend ActiveSupport::Concern

  included do
    validate :email_is_unique

    validates :email,
              email: {
                mx: !ENV['RAILS_OFFLINE'],
                ban_disposable_email: true
              }
  end

  def email_taken?
    @email_taken == true
  end

  private

  def email_is_unique
    return if persisted? && email == @user.email

    @email_taken = true if User.exists?(email: email)
  end
end
