module BillableEventTrackable
  def track_billing_events(service_provider:)
    if current_session_has_been_billed?
      create_sp_return_log(billable: false, service_provider: service_provider)
    else
      create_sp_return_log(billable: true, service_provider: service_provider)
      mark_current_session_billed
    end
  end

  private

  def create_sp_return_log(service_provider:, billable:)
    user_ial_context = IalContext.new(
      ial: ial_context.ial, service_provider: current_sp, user: current_user,
    )
    binding.pry
    Db::SpReturnLog.create_return(
      request_id: request_id,
      user_id: current_user.id,
      billable: billable,
      ial: user_ial_context.bill_for_ial_1_or_2,
      issuer: current_sp.issuer,
      requested_at: session[:session_started_at],
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

    if sp_session_ial == 1
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
