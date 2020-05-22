module AccountReset
  class Cancel
    include ActiveModel::Model
    include CancelTokenValidator

    def initialize(token)
      @token = token
    end

    def call
      @success = valid?

      if success
        AccountReset::NotifyUserOfRequestCancellation.new(user).call
        update_account_reset_request
      end

      FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
    end

    private

    attr_reader :success, :token

    def update_account_reset_request
      account_reset_request.update!(cancelled_at: Time.zone.now,
                                    request_token: nil,
                                    granted_token: nil)
    end

    def user
      account_reset_request&.user || AnonymousUser.new
    end

    def extra_analytics_attributes
      {
        event: 'cancel',
        user_id: user.uuid,
      }
    end
  end
end
