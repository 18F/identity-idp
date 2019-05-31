module FormAddEmailValidator
  extend ActiveSupport::Concern

  included do
    include ActiveModel::Validations::Callbacks

    before_validation :downcase_and_strip

    validate :check_max_emails_per_account
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

  def check_max_emails_per_account
    return if EmailPolicy.new(@user).can_add_email?
    errors.add(:email, :already_confirmed)
  end

  def email_is_available_to_user
    email_address = EmailAddress.find_with_email(email)
    @email_taken = true if email_address&.user_id == @user.id
  end
end
