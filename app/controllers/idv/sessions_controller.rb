module Idv
  class SessionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated

    def destroy
      analytics.track_event(Analytics::IDV_VERIFICATION_ATTEMPT_CANCELLED)
      Idv::CancelVerificationAttempt.new(user: current_user).call
      user_session['idv/doc_auth'] = {}
      idv_session.clear
      user_session.delete(:decrypted_pii)
      redirect_to idv_url
    end
  end
end
