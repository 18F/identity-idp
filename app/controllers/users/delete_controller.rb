module Users
  class DeleteController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated

    def show; end

    def delete
      current_user.destroy!
      sign_out
      flash[:success] = t('devise.registrations.destroyed')
      redirect_to root_url
    end
  end
end
