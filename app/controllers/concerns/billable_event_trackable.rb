# frozen_string_literal: true

module BillableEventTrackable
  def track_billing_events
    if current_session_has_been_billed?
      create_sp_return_log(billable: false)
    else
      create_sp_return_log(billable: true)
      mark_current_session_billed
    end
  end

  private

  def create_sp_return_log(billable:)
    SpReturnLog.create(
      request_id: request_id,
      user: current_user,
      billable: billable,
      ial: ial_context.bill_for_ial_1_or_2,
      issuer: current_sp.issuer,
      profile_id: ial_context.bill_for_ial_1_or_2 > 1 ? current_user.active_profile&.id : nil,
      profile_verified_at: ial_context.bill_for_ial_1_or_2 > 1 ?
        current_user.active_profile&.verified_at : nil,
      profile_requested_issuer: ial_context.bill_for_ial_1_or_2 > 1 ?
        current_user.active_profile&.initiating_service_provider_issuer : nil,
      requested_at: session[:session_started_at],
      returned_at: Time.zone.now,
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def current_session_has_been_billed?
    user_session[session_has_been_billed_flag_key] == true
  end

  def mark_current_session_billed
    user_session[session_has_been_billed_flag_key] = true
  end

  # The flags are formatted in this way to preserve continuity across sessions.
  # This prevents issues where billable transactions are tracked one way on
  # old instances and a different way on new instances.
  def session_has_been_billed_flag_key
    issuer = sp_session[:issuer]

    if !resolved_authn_context_result.identity_proofing?
      "auth_counted_#{issuer}ial1"
    else
      "auth_counted_#{issuer}"
    end
  end

  def first_visit_for_sp?
    issuer = sp_session[:issuer]
    # check if the user has visited this SP at either IAL1 or IAL2 in this session
    !user_session["auth_counted_#{issuer}ial1"] && !user_session["auth_counted_#{issuer}"]
  end
end
