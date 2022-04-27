module AccountReset
  class ValidateGrantedToken
    include ActiveModel::Model
    include GrantedTokenValidator

    def initialize(token)
      @token = token
    end

    def call
      @success = valid?

      FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
    end

    private

    attr_reader :success

    def extra_analytics_attributes
      {
        user_id: user.uuid,
      }
    end
  end
end
