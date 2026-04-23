# frozen_string_literal: true

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
      FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
    end

    private

    def handle_valid_password
      update_user
      mark_profile_inactive
    end

    def update_user
      user.update!(password: password)
    end

    def mark_profile_inactive
      return if user.active_profile.blank?

      user.active_profile&.deactivate(:password_reset)
      user.reload
      Funnel::DocAuth::ResetSteps.call(@user.id)
    end

    def extra_analytics_attributes
      EventDisavowal::BuildDisavowedEventAnalyticsAttributes.call(event)
    end
  end
end
