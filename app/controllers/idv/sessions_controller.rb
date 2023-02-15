module Idv
  class SessionsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated

    def destroy
      cancel_processing
      path = request_came_from
      clear_session
      log_analytics(path)
      redirect_to idv_url
    end

    private

    def enrollment
      return InPersonEnrollment.where(user_id: current_user.id).first
    end

    def request_came_from
      return user_session.dig(:idv, :go_back_path)
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

    def log_analytics(path)
      if path == '/verify/in_person/ready_to_verify'
        analytics.idv_cancellation_visited_from_barcode_page(
          cancelled: true,
          enrollment_code: enrollment.enrollment_code,
          enrollment_id: enrollment.id,
          service_provider: decorated_session.sp_name || APP_NAME,
        )
      end
      analytics.idv_start_over(
        step: location_params[:step],
        location: location_params[:location],
      )
    end
  end
end
