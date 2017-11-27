module Users
  class VerifyAccountController < ApplicationController
    before_action :confirm_two_factor_authenticated
    before_action :confirm_verification_needed

    def index
      usps_mail = Idv::UspsMail.new(current_user)
      @mail_spammed = usps_mail.mail_spammed?
      @verify_account_form = VerifyAccountForm.new(user: current_user)

      return unless FeatureManagement.reveal_usps_code?
      @code = session[:last_usps_confirmation_code]
    end

    def create
      @verify_account_form = build_verify_account_form

      if @verify_account_form.submit
        flash[:success] = t('account.index.verification.success')
        redirect_to sign_up_completed_url
      else
        render :index
      end
    end

    private

    def build_verify_account_form
      VerifyAccountForm.new(
        user: current_user,
        otp: params_otp
      )
    end

    def params_otp
      params[:verify_account_form].permit(:otp)[:otp]
    end

    def confirm_verification_needed
      return if current_user.decorate.pending_profile_requires_verification?
      redirect_to account_url
    end
  end
end
