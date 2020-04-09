module Idv
  class ScanIdController < ScanIdBaseController
    before_action :ensure_fully_authenticated_user_or_token
    before_action :ensure_user_not_throttled, only: [:new]
    USER_SESSION_FLOW_ID = 'idv/doc_auth_v2'.freeze

    def new
      SecureHeaders.append_content_security_policy_directives(request,
                                                              script_src: ['\'unsafe-eval\''])
      render layout: false
    end

    def scan_complete
      if all_checks_passed?
        save_proofing_components
        token_user_id ? continue_to_ssn_on_desktop : continue_to_ssn
      else
        idv_failure
      end
      clear_scan_id_session
    end

    private

    def flow_session
      user_session[USER_SESSION_FLOW_ID]
    end

    def ensure_fully_authenticated_user_or_token
      return if user_signed_in? && user_fully_authenticated?
      ensure_user_id_in_session
    end

    def ensure_user_id_in_session
      return if token_user_id && token.blank?
      result = CaptureDoc::ValidateRequestToken.new(token).call
      analytics.track_event(Analytics::DOC_AUTH, result.to_h)
      process_result(result)
    end

    def process_result(result)
      if result.success?
        reset_session
        session[:token_user_id] = result.extra[:for_user_id]
      else
        flash[:error] = t('errors.capture_doc.invalid_link')
        redirect_to root_url
      end
    end

    def all_checks_passed?
      scan_id_session && scan_id_session[:instance_id] && scan_id_session[:facematch_pass] &&
        (scan_id_session[:liveness_pass] || !FeatureManagement.liveness_checking_enabled?)
    end

    def token
      params[:token]
    end

    def continue_to_ssn_on_desktop
      CaptureDoc::UpdateAcuantToken.call(token_user_id,
                                         scan_id_session[:instance_id])
      render :capture_complete
    end

    def continue_to_ssn
      flow_session[:pii_from_doc] = scan_id_session[:pii]
      flow_session[:pii_from_doc]['uuid'] = current_user.uuid
      user_session[USER_SESSION_FLOW_ID]['Idv::Steps::ScanIdStep'] = true
      redirect_to idv_doc_auth_v2_step_url(step: :ssn)
    end

    def clear_scan_id_session
      session.delete(:scan_id)
      session.delete(:token_user_id)
    end

    def ensure_user_not_throttled
      redirect_to idv_session_errors_throttled_url if attempter_throttled?
    end

    def idv_failure
      if attempter_throttled?
        redirect_to idv_session_errors_throttled_url
      else
        redirect_to idv_session_errors_warning_url
      end
    end

    def save_proofing_components
      save_proofing_component(:document_check, 'acuant')
      save_proofing_component(:document_type, 'state_id')
      save_proofing_component(:liveness_check, 'acuant') if scan_id_session[:liveness_pass]
    end

    def save_proofing_component(key, value)
      Db::ProofingComponent::Add.call(current_user_id, key, value)
    end
  end
end
