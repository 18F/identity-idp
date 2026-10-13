# frozen_string_literal: true

module BillableEventTrackable
  def track_billing_events
    if current_session_has_been_billed?
      create_sp_return_log(billable: false)
    else
      row = create_sp_return_log(billable: true)
      mark_current_session_billed
      remember_sign_in_row_for_delegated_billing(row)
    end
    link_sign_in_for_delegated_billing
  end

  private

  # The direct sign-in row, written through the shared writer so its columns are computed the
  # same way as a delegated row's. A repeat of the same request id is dropped silently.
  def create_sp_return_log(billable:)
    Billing::SpReturnLogWriter.write(
      user: current_user,
      issuer: current_sp.issuer,
      ial: ial_context.bill_for_ial_1_or_2,
      request_id: request_id,
      billable: billable,
      access_type: SpReturnLog::ACCESS_TYPE_DIRECT,
    )
  end

  # For a service provider approved for delegated access, the id of the session's billable
  # sign-in row is kept so that a later handoff in the same session (which writes a non-billable
  # row or nothing) still points the waiver link at the row that is actually invoiced.
  def remember_sign_in_row_for_delegated_billing(row)
    return unless current_sp.delegation_service_provider? && row&.persisted? && row.billable

    user_session[delegated_billing_row_key] = row.id
  end

  # Links the sign-in to the access token the service provider is about to receive, so an
  # exchange of that token can waive the sign-in's billing in favor of the agency receiving the
  # delegated token. The token was set on the identity when it was linked just before this
  # handoff. A failure to write the link never affects the handoff: the exchange falls back to
  # the database to find the sign-in.
  def link_sign_in_for_delegated_billing
    return unless current_sp.delegation_service_provider?

    identity = current_user.identities.find_by(service_provider: current_sp.issuer)
    Billing::SignInWaiverLink.write(
      access_token: identity&.access_token,
      sp_return_log_id: user_session[delegated_billing_row_key],
    )
  rescue StandardError => error
    NewRelic::Agent.notice_error(error)
  end

  def delegated_billing_row_key
    "delegated_billing_return_log_#{sp_session[:issuer]}"
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
