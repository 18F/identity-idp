module Idv
  class SessionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated

    def destroy
      cancel_processing
      clear_session
      log_analytics
      redirect_to idv_url
    end

    private

    def barcode_step
      return params[:step] == 'barcode'
    end

    def enrollment
      return InPersonEnrollment.where(user_id: current_user.id).first
    end

    def extra_analytics_attributes
      {
        cancelled_enrollment: true,
        enrollment_code: enrollment.enrollment_code,
        enrollment_id: enrollment.id,
        service_provider: decorated_session.sp_name || APP_NAME,
      }
    end

    def location_params
      params.permit(:step, :location).to_h.symbolize_keys
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
      user_session['idv/inherited_proofing'] = {}
      idv_session.clear
      Pii::Cacher.new(current_user, user_session).delete
    end

    def log_analytics
      analytics.idv_start_over(
        step: location_params[:step],
        location: location_params[:location],
        extra: barcode_step ? extra_analytics_attributes : nil,
      )
    end
  end
end
