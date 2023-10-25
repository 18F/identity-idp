# frozen_string_literal: true

module AccountReset
  class ValidateGrantedToken
    include ActiveModel::Model
    include GrantedTokenValidator
    include TrackIrsEvent

    def initialize(token, request, analytics)
      @token = token
      @request = request
      @analytics = analytics
    end

    def call
      @success = valid?
      track_irs_event if !success && sp
      FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
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
