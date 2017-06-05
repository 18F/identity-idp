module Users
  class VerifyPasswordController < ApplicationController
    include AccountRecoveryConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_password_reset_profile
    before_action :confirm_personal_key

    def new
      @verify_password_form = VerifyPasswordForm.new(
        user: current_user,
        password: '',
        decrypted_pii: decrypted_pii
      )
    end

    def update
      result = verify_password_form.submit

      if result.success?
        flash[:personal_key] = result.extra[:personal_key]
        user_session.delete(:account_recovery)
        redirect_to account_url
      else
        render :new
      end
    end

    private

    def confirm_personal_key
      account_recovery = user_session[:account_recovery]
      redirect_to root_url unless account_recovery[:personal_key]
    end

    def decrypted_pii
      @_decrypted_pii ||= Pii::Attributes.new_from_json(user_session[:decrypted_pii])
    end

    def verify_password_form
      VerifyPasswordForm.new(
        user: current_user,
        password: params.require(:user).permit(:password)[:password],
        decrypted_pii: decrypted_pii
      )
    end
  end
end
