module AccountResetCancelTokenValidator
  extend ActiveSupport::Concern

  included do
    validates :token, presence: true
    validate :valid_token
  end

  private

  def valid_token
    return if account_reset_request

    errors.add(:token, 'invalid')
  end
end
