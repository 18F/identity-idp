module Users
  class DeleteController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated

    def show; end

    def delete
      send_push_notifications
      current_user.destroy!
      sign_out
      flash[:success] = t('devise.registrations.destroyed')
      redirect_to root_url
    end

    private

    def send_push_notifications
      return if Figaro.env.push_notifications_enabled != 'true'
      PushNotification::AccountDelete.new.call(current_user.id)
    end
  end
end
