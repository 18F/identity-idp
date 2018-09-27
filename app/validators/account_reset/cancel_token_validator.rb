module AccountReset
  module CancelTokenValidator
    extend ActiveSupport::Concern

    included do
      validates :token, presence: { message: I18n.t('errors.account_reset.cancel_token_missing') }
      validate :valid_token
    end

    private

    attr_reader :token

    def valid_token
      return if account_reset_request

      errors.add(:token, I18n.t('errors.account_reset.cancel_token_invalid')) if token
    end

    def account_reset_request
      @account_reset_request ||= AccountResetRequest.find_by(request_token: token)
    end
  end
end
