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
    email_address = EmailAddress.find_with_email(email)
    email_owner = email_address&.user

    return if email_owner.blank?
    return if email_owner == @user

    return @email_taken = true unless email_owner.confirmed?
    @email_take = true if email_address.confirmed?
  end
end
