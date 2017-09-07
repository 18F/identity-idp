module Users
  class DeleteController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated

    def show; end

    def delete
      result = DeleteUserForm.new(current_user).submit

      analytics.track_event(Analytics::USER_DELETE, {})

      redirect_to root_path
    end
  end
end
