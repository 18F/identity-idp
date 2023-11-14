module IdvStepConcern
  extend ActiveSupport::Concern

  include IdvSession
  include RateLimitConcern
  include FraudReviewConcern
  include Idv::AbTestAnalyticsConcern

  included do
    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_no_pending_gpo_profile
    before_action :confirm_no_pending_in_person_enrollment
    before_action :handle_fraud
    before_action :check_for_mail_only_outage
  end

  def confirm_no_pending_gpo_profile
    redirect_to idv_verify_by_mail_enter_code_url if current_user&.gpo_verification_pending_profile?
  end

  def confirm_no_pending_in_person_enrollment
    return if !IdentityConfig.store.in_person_proofing_enabled
    redirect_to idv_in_person_ready_to_verify_url if current_user&.pending_in_person_enrollment
  end

  def check_for_mail_only_outage
    return if idv_session.mail_only_warning_shown

    return redirect_for_mail_only if FeatureManagement.idv_by_mail_only?
  end

  def redirect_for_mail_only
    return redirect_to vendor_outage_url unless FeatureManagement.gpo_verification_enabled?

    redirect_to idv_mail_only_warning_url
  end

  def pii_from_user
    flow_session['pii_from_user']
  end

  def flow_path
    idv_session.flow_path
  end

  def confirm_hybrid_handoff_needed
    if params[:redo]
      idv_session.redo_document_capture = true
    end

    # If we previously skipped hybrid handoff, keep doing that.
    # If hybrid flow is unavailable, skip it.
    # But don't store that we skipped it in idv_session, in case it is back to
    # available when the user tries to redo document capture.
    if idv_session.skip_hybrid_handoff? || !FeatureManagement.idv_allow_hybrid_flow?
      idv_session.flow_path = 'standard'
      redirect_to idv_document_capture_url
    end
  end

  private

  def confirm_ssn_step_complete
    return if pii.present? && idv_session.ssn.present?
    redirect_to prev_url
  end

  def confirm_document_capture_complete
    return if idv_session.pii_from_doc.present?

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

    if current_user.has_in_person_enrollment?
      redirect_to idv_in_person_verify_info_url
    else
      redirect_to idv_verify_info_url
    end
  end

  def confirm_verify_info_step_needed
    return unless idv_session.verify_info_step_complete?
    redirect_to idv_enter_password_url
  end

  def confirm_address_step_complete
    return if idv_session.address_step_complete?

    redirect_to idv_otp_verification_url
  end

  def extra_analytics_properties
    extra = {
      pii_like_keypaths: [[:same_address_as_id], [:state_id, :state_id_jurisdiction]],
    }

    unless flow_session.dig(:pii_from_user, :same_address_as_id).nil?
      extra[:same_address_as_id] =
        flow_session[:pii_from_user][:same_address_as_id].to_s == 'true'
    end
    extra
  end

  def flow_policy
    @flow_policy ||= Idv::FlowPolicy.new(idv_session: idv_session, user: current_user)
  end

  def confirm_step_allowed
    return if flow_policy.controller_allowed?(controller: self.class)

    redirect_to url_for_latest_step
  end

  def url_for_latest_step
    step_info = flow_policy.info_for_latest_step
    url_for(controller: step_info.controller, action: step_info.action)
  end
end
