module Users
  class VerifyAccountController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_verification_needed

    def index
      analytics.track_event(Analytics::ACCOUNT_VERIFICATION_VISITED)
      usps_mail = Idv::UspsMail.new(current_user)
      @mail_spammed = usps_mail.mail_spammed?
      @verify_account_form = VerifyAccountForm.new(user: current_user)
      @code = session[:last_gpo_confirmation_code] if FeatureManagement.reveal_usps_code?

      if Throttler::IsThrottled.call(current_user.id, :verify_gpo_key)
        render :throttled
      else
        render :index
      end
    end

    def create
      @verify_account_form = build_verify_account_form

      throttled = Throttler::IsThrottledElseIncrement.call(
        current_user.id,
        :verify_gpo_key,
      )

      if throttled
        render :throttled
      else
        result = @verify_account_form.submit
        analytics.track_event(Analytics::ACCOUNT_VERIFICATION_SUBMITTED, result.to_h)

        if result.success?
          create_user_event(:account_verified)
          flash[:success] = t('account.index.verification.success')
          redirect_to sign_up_completed_url
        else
          render :index
        end
      end
    end

    private

    def build_verify_account_form
      VerifyAccountForm.new(
        user: current_user,
        otp: params_otp,
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
