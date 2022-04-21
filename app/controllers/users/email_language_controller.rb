module Users
  class EmailLanguageController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      analytics.email_language_visited
    end

    def update
      form_response = UpdateEmailLanguageForm.new(current_user).submit(update_email_params)
      analytics.email_language_updated(**form_response.to_h)

      flash[:success] = I18n.t('account.email_language.updated') if form_response.success?

      redirect_to account_path
    end

    private

    def update_email_params
      params.require(:user).permit(:email_language)
    end
  end
end
