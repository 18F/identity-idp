module FormEmailValidator
  extend ActiveSupport::Concern

  included do
    include ActiveModel::Validations::Callbacks

    before_validation :downcase_and_strip

    validate :validate_domain
    validates :email,
              email: {
                mx_with_fallback: !ENV['RAILS_OFFLINE'],
                ban_disposable_email: true,
              }
  end

  private

  def validate_domain
    return unless email.present?
    domain = Mail::Address.new(email).domain

    if domain && !domain.ascii_only?
      errors.add(:email, t('valid_email.validations.email.invalid'), type: :domain)
    end
  end

  def downcase_and_strip
    self.email = email&.downcase&.strip
  end
end
