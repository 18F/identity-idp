# frozen_string_literal: true

module AccountReset
  class ValidateCancelToken
    include ActiveModel::Model
    include CancelTokenValidator

    def initialize(token)
      @token = token
    end

    def call
      @success = valid?

      FormResponse.new(
        success:,
        errors:,
        extra: extra_analytics_attributes,
        serialize_error_details_only: false,
      )
    end

    private

    attr_reader :success, :token

    def user
      account_reset_request&.user || AnonymousUser.new
    end

    def extra_analytics_attributes
      {
        user_id: user.uuid,
      }
    end
  end
end
