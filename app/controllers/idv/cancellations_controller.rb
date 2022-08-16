module Idv
  class CancellationsController < ApplicationController
    include IdvSession
    include GoBackHelper

    before_action :confirm_idv_needed

    def new
      properties = ParseControllerFromReferer.new(request.referer).call
      analytics.idv_cancellation_visited(step: params[:step], **properties)
      self.session_go_back_path = go_back_path || idv_path
      @hybrid_session = hybrid_session?
      @presenter = CancellationsPresenter.new(
        sp_name: decorated_session.sp_name,
        url_options: url_options,
      )
    end

    def update
      analytics.idv_cancellation_go_back(step: params[:step])
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

    private

    def cancel_session
      if hybrid_session?
        cancel_document_capture_session
      else
        cancel_in_person_enrollment_if_exists
        idv_session = user_session[:idv]
        idv_session&.clear
        user_session['idv/in_person'] = {}
        reset_doc_auth
      end
    end

    def cancelled_redirect_path
      if decorated_session.sp_name
        return_to_sp_failure_to_proof_path(location_params)
      else
        account_path
      end
    end

    def location_params
      params.permit(:step, :location).to_h.symbolize_keys
    end

    def reset_doc_auth
      user_session.delete('idv/doc_auth')
      user_session['idv'] = {}
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
