module BillableEventTrackable
  extend ActiveSupport::Concern

  def track_billing_events
    if current_session_has_been_billed?
      update_sp_return_log(billable: false)
    else
      increment_sp_monthly_auths
      update_sp_return_log(billable: true)
      mark_current_session_billed
      add_sp_cost(:authentication)
    end
  end

  private

  def increment_sp_monthly_auths
    issuer = sp_session[:issuer]
    MonthlySpAuthCount.increment(current_user.id, issuer, sp_session_ial)
  end

  def update_sp_return_log(billable:)
    Db::SpReturnLog.add_return(request_id, current_user.id, billable)
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
end
