module Users
  class VerifyAccountController < ApplicationController
    before_action :confirm_verification_needed

    def index
      @verify_account_form = VerifyAccountForm.new(user: current_user)
    end

    def create
      @verify_account_form = build_verify_account_form
      if @verify_account_form.submit
        flash[:success] = t('account.index.verification.success')
        redirect_to account_path
      else
        render :index
      end
    end

    private

    def build_verify_account_form
      VerifyAccountForm.new(
        user: current_user,
        otp: params_otp,
        pii_attributes: decrypted_pii
      )
    end

    def params_otp
      params[:verify_account_form].permit(:otp)[:otp]
    end

    def confirm_verification_needed
      current_user.active_profile.blank? && current_user.decorate.pending_profile.present?
    end

    def decrypted_pii
      cacher = Pii::Cacher.new(current_user, user_session)
      cacher.fetch
    end
  end
end
