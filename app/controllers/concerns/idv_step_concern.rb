module IdvStepConcern
  extend ActiveSupport::Concern

  include IdvSession
  include RateLimitConcern
  include FraudReviewConcern
  include Idv::OutageConcern

  included do
    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_not_rate_limited
    before_action :confirm_no_pending_gpo_profile
    before_action :confirm_no_pending_in_person_enrollment
    before_action :handle_fraud
    before_action :check_for_outage
  end

  def confirm_no_pending_gpo_profile
    redirect_to idv_gpo_verify_url if current_user&.gpo_verification_pending_profile?
  end

  def confirm_no_pending_in_person_enrollment
    return if !IdentityConfig.store.in_person_proofing_enabled
    redirect_to idv_in_person_ready_to_verify_url if current_user&.pending_in_person_enrollment
  end

  def pii_from_doc
    flow_session['pii_from_doc']
  end

  # copied from doc_auth_controller
  def flow_path
    idv_session.flow_path || flow_session[:flow_path]
  end

  private

  def confirm_ssn_step_complete
    return if pii.present? && pii[:ssn].present?
    redirect_to prev_url
  end

  def confirm_document_capture_complete
    return if pii_from_doc.present?

    if flow_path == 'standard'
      redirect_to idv_document_capture_url
    elsif flow_path == 'hybrid'
      redirect_to idv_link_sent_url
    else # no flow_path
      redirect_to idv_hybrid_handoff_path
    end
  end

  def confirm_verify_info_step_complete
    return if idv_session.verify_info_step_complete?

    if idv_session.in_person_enrollment?
      redirect_to idv_in_person_verify_info_url
    else
      redirect_to idv_verify_info_url
    end
  end

  def confirm_verify_info_step_needed
    return unless idv_session.verify_info_step_complete?
    redirect_to idv_review_url
  end

  def confirm_address_step_complete
    return if idv_session.address_step_complete?

    redirect_to idv_otp_verification_url
  end
end
