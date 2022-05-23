module Idv
  class SessionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated

    def destroy
      cancel_verification_attempt_if_pending_profile
      analytics.idv_start_over(
        step: location_params[:step],
        location: location_params[:location],
      )
      user_session['idv/doc_auth'] = {}
      idv_session.clear
      Pii::Cacher.new(current_user, user_session).delete
      redirect_to idv_url
    end

    private

    def cancel_verification_attempt_if_pending_profile
      return if current_user.profiles.verification_pending.blank?
      Idv::CancelVerificationAttempt.new(user: current_user).call
    end

    def location_params
      params.permit(:step, :location).to_h.symbolize_keys
    end
  end
end
