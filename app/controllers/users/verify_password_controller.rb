module Users
  class VerifyPasswordController < ApplicationController
    include AccountReactivationConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_password_reset_profile
    before_action :confirm_personal_key

    def new
      @decrypted_pii = decrypted_pii
    end

    def update
      @decrypted_pii = decrypted_pii
      result = verify_password_form.submit

      if result.success?
        handle_success(result)
      else
        flash[:error] = t('errors.messages.password_incorrect')
        render :new
      end
    end

    private

    def confirm_personal_key
      return if reactivate_account_session.validated_personal_key?
      redirect_to root_url
    end

    # rubocop:disable Naming/MemoizedInstanceVariableName
    # @return [Pii::Attributes, nil]
    def decrypted_pii
      @_decrypted_pii ||= reactivate_account_session.decrypted_pii
    end
    # rubocop:enable Naming/MemoizedInstanceVariableName

    def handle_success(result)
      flash[:personal_key] = result.extra[:personal_key]
      reactivate_account_session.clear
      redirect_to account_url
    end

    def verify_password_form
      VerifyPasswordForm.new(
        user: current_user,
        password: params.require(:user).permit(:password)[:password],
        decrypted_pii: decrypted_pii,
      )
    end
  end
end
