module Users
  class VerifyProfileController < ApplicationController
    before_action :confirm_verification_needed

    def index
      @verify_profile_form = VerifyProfileForm.new(user: current_user)
    end

    def create
      @verify_profile_form = build_verify_profile_form
      if @verify_profile_form.submit
        flash[:success] = t('profile.index.verification.success')
        redirect_to profile_path
      else
        render :index
      end
    end

    private

    def build_verify_profile_form
      VerifyProfileForm.new(
        user: current_user,
        otp: params_otp,
        pii_attributes: decrypted_pii
      )
    end

    def params_otp
      params[:verify_profile_form].permit(:otp)[:otp]
    end

    def confirm_verification_needed
      !current_user.active_profile.present? && current_user.decorate.pending_profile.present?
    end

    def decrypted_pii
      cacher = Pii::Cacher.new(current_user, user_session)
      cacher.fetch
    end
  end
end
