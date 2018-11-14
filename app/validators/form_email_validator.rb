module FormEmailValidator
  extend ActiveSupport::Concern

  included do
    include ActiveModel::Validations::Callbacks

    before_validation :downcase_and_strip

    validate :email_is_unique

    validates :email,
              email: {
                mx_with_fallback: !ENV['RAILS_OFFLINE'],
                ban_disposable_email: true,
              }
  end

  def email_taken?
    @email_taken == true
  end

  private

  def downcase_and_strip
    self.email = email&.downcase&.strip
  end

  def email_is_unique
    email_owner = EmailAddress.find_with_email(email)&.user
    return if persisted? && email_owner == @user

    @email_taken = true if email_owner
  end
end
