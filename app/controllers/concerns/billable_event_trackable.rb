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
