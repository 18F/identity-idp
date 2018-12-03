module AccountReset
  class ValidateCancelToken
    include ActiveModel::Model
    include CancelTokenValidator

    def initialize(token)
      @token = token
    end

    def call
      @success = valid?

      FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
    end

    private

    attr_reader :success, :token

    def user
      account_reset_request&.user || AnonymousUser.new
    end

    def extra_analytics_attributes
      {
        event: 'cancel token validation',
        user_id: user.uuid,
      }
    end
  end
end
