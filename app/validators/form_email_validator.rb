module FormEmailValidator
  extend ActiveSupport::Concern

  included do
    include ActiveModel::Validations::Callbacks

    before_validation :downcase_and_strip

    validates :email, email: { mx_with_fallback: !ENV['RAILS_OFFLINE'], ban_disposable_email: true }
  end

  private

  def downcase_and_strip
    self.email = email&.downcase&.strip
  end
end
