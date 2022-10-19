module Idv
  class SessionsController < ApplicationController
    include IdvSession
    include InheritedProofingSession

    before_action :confirm_two_factor_authenticated

    def destroy
      destroy_idv
      destroy_inherited_proofing if inherited_proofing?
      redirect_to idv_url
    end

    private

    def location_params
      params.permit(:step, :location).to_h.symbolize_keys
    end

    def destroy_idv
      cancel_processing
      clear_session
      log_analytics
    end

    def cancel_processing
      cancel_verification_attempt_if_pending_profile
      cancel_in_person_enrollment_if_exists
    end

    def cancel_verification_attempt_if_pending_profile
      return if current_user.profiles.gpo_verification_pending.blank?
      Idv::CancelVerificationAttempt.new(user: current_user).call
    end

    def cancel_in_person_enrollment_if_exists
      return if !IdentityConfig.store.in_person_proofing_enabled
      current_user.pending_in_person_enrollment&.update(status: :cancelled)
      UspsInPersonProofing::EnrollmentHelper.
        cancel_stale_establishing_enrollments_for_user(current_user)
    end

    def clear_session
      user_session['idv/doc_auth'] = {}
      user_session['idv/in_person'] = {}
      idv_session.clear
      Pii::Cacher.new(current_user, user_session).delete
    end

    def log_analytics
      analytics.idv_start_over(
        step: location_params[:step],
        location: location_params[:location],
      )
    end
  end
end
