module FormEmailValidator
  extend ActiveSupport::Concern

  included do
    include ActiveModel::Validations::Callbacks

    before_validation :downcase_and_strip

    validates :email,
              email: {
                mx_with_fallback: !ENV['RAILS_OFFLINE'],
                ban_disposable_email: true,
              }
    validate :validate_domain
  end

  private

  def validate_domain
    return unless email.present? && errors.blank?
    domain = Mail::Address.new(email).domain

    if domain && !domain.ascii_only?
      errors.add(:email, t('valid_email.validations.email.invalid'), type: :domain)
    end
  rescue Mail::Field::IncompleteParseError
    errors.add(:email, t('valid_email.validations.email.invalid'), type: :domain)
  end

  def downcase_and_strip
    self.email = email&.downcase&.strip
  end
end
