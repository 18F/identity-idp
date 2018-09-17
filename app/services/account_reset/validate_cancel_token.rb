module AccountReset
  class ValidateCancelToken
    include ActiveModel::Model

    validates :token, presence: { message: I18n.t('errors.account_reset.cancel_token_missing') }
    validate :valid_token

    def initialize(token)
      @token = token
    end

    def call
      @success = valid?

      FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
    end

    private

    attr_reader :success, :token, :validate_and_cancel

    def valid_token
      return if account_reset_request

      errors.add(:token, I18n.t('errors.account_reset.cancel_token_invalid')) if token
    end

    def account_reset_request
      @account_reset_request ||= AccountResetRequest.find_by(request_token: token)
    end

    def user
      account_reset_request&.user || AnonymousUser.new
    end

    def extra_analytics_attributes
      {
        event: 'visit',
        user_id: user.uuid,
      }
    end
  end
end
