module FormAddEmailValidator
  extend ActiveSupport::Concern

  included do
    include ActiveModel::Validations::Callbacks

    before_validation :downcase_and_strip

    validate :email_is_available_to_user

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

  def email_is_available_to_user
    email_address = EmailAddress.find_with_email(email)
    return unless email_address&.user_id == @user.id
    errors.add(:email, I18n.t('email_addresses.add.duplicate'))
  end
end
