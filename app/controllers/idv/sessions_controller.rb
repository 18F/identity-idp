module Idv
  class SessionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated

    def destroy
      cancel_verification_attempt_if_pending_profile
      analytics.track_event(Analytics::IDV_START_OVER, **location_params)
      user_session['idv/doc_auth'] = {}
      idv_session.clear
      user_session.delete(:decrypted_pii)
      redirect_to idv_url
    end

    private

    def cancel_verification_attempt_if_pending_profile
      return if current_user.profiles.verification_pending.blank?
      analytics.track_event(Analytics::IDV_VERIFICATION_ATTEMPT_CANCELLED)
      Idv::CancelVerificationAttempt.new(user: current_user).call
    end

    def location_params
      params.permit(:step, :location).to_h.symbolize_keys
    end
  end
end
