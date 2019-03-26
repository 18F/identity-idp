module Recover
  class ValidateRequestToken
    include ActiveModel::Model
    include Idv::RecoverTokenValidator

    def initialize(token)
      @token = token
    end

    def call
      @success = valid?

      FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
    end

    private

    attr_reader :success

    def extra_analytics_attributes
      {
        for_user_id: recover_request&.user_id,
        user_id: 'anonymous-uuid',
        event: 'Request token validation',
      }
    end
  end
end
