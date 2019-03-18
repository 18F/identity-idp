module EventDisavowal
  class PasswordResetFromDisavowalForm
    include ActiveModel::Model
    include FormPasswordValidator

    attr_reader :event, :user

    def initialize(event)
      @event = event
      @user = event.user
    end

    def submit(params)
      self.password = params[:password]

      success = valid?
      handle_valid_password if success
      FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
    end

    private

    def handle_valid_password
      update_user
      mark_profile_inactive
    end

    def update_user
      attributes = { password: password }
      UpdateUser.new(user: user, attributes: attributes).call
    end

    def mark_profile_inactive
      user.active_profile&.deactivate(:password_reset)
    end

    def extra_analytics_attributes
      EventDisavowal::BuildDisavowedEventAnalyticsAttributes.call(event)
    end
  end
end
