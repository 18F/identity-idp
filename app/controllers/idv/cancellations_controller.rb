module Idv
  class CancellationsController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvSession
    include GoBackHelper

    before_action :confirm_idv_needed

    def new
      analytics.idv_cancellation_visited(step: params[:step], **properties)
      self.session_go_back_path = go_back_path || idv_path
      @hybrid_session = hybrid_session?
      @presenter = CancellationsPresenter.new(
        sp_name: decorated_sp_session.sp_name,
        url_options: url_options,
      )
    end

    def update
      analytics.idv_cancellation_go_back(
        step: params[:step],
        **extra_analytics_attributes,
      )
      redirect_to session_go_back_path || idv_path
    end

    def destroy
      analytics.idv_cancellation_confirmed(step: params[:step])
      cancel_session
      if hybrid_session?
        render :destroy
      else
        render json: { redirect_url: cancelled_redirect_path }
      end
    end

    def exit
      analytics.idv_cancellation_confirmed(step: params[:step])
      cancel_session
      if hybrid_session?
        render :destroy
      else
        redirect_to cancelled_redirect_path
      end
    end

    private

    def barcode_step?
      params[:step] == 'barcode'
    end

    def enrollment
      current_user.pending_in_person_enrollment
    end

    def extra_analytics_attributes
      extra = {}
      if barcode_step? && enrollment
        extra.merge!(
          cancelled_enrollment: false,
          enrollment_code: enrollment.enrollment_code,
          enrollment_id: enrollment.id,
        )
      end
      extra
    end

    def properties
      ParseControllerFromReferer.new(request.referer).call
    end

    def cancel_session
      if hybrid_session?
        cancel_document_capture_session
      else
        cancel_in_person_enrollment_if_exists
        idv_session = user_session[:idv]
        idv_session&.clear
        user_session['idv/in_person'] = {}
      end
    end

    def cancelled_redirect_path
      if decorated_sp_session.sp_name
        return_to_sp_failure_to_proof_path(location_params)
      else
        account_path
      end
    end

    def location_params
      params.permit(:step, :location).to_h.symbolize_keys
    end

    def cancel_document_capture_session
      document_capture_session&.update(cancelled_at: Time.zone.now)
    end

    def document_capture_session_uuid
      session[:document_capture_session_uuid]
    end

    def document_capture_session
      DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
    end

    def session_go_back_path=(path)
      if hybrid_session?
        session[:go_back_path] = path
      else
        idv_session.go_back_path = path
      end
    end

    def session_go_back_path
      if hybrid_session?
        session[:go_back_path]
      else
        idv_session.go_back_path
      end
    end

    def cancel_in_person_enrollment_if_exists
      return if !IdentityConfig.store.in_person_proofing_enabled
      current_user.pending_in_person_enrollment&.update(status: :cancelled)
      UspsInPersonProofing::EnrollmentHelper.
        cancel_stale_establishing_enrollments_for_user(current_user)
    end
  end
end
