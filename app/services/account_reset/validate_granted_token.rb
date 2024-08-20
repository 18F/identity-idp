# frozen_string_literal: true

module AccountReset
  class ValidateGrantedToken
    include ActiveModel::Model
    include GrantedTokenValidator

    def initialize(token, request, analytics)
      @token = token
      @request = request
      @analytics = analytics
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

    attr_reader :success, :request, :analytics

    def extra_analytics_attributes
      {
        user_id: user.uuid,
      }
    end
  end
end
