module DeviceProfilingConcern
  extend ActiveSupport::Concern

  def grab_device_profiling_result(type)
    return unless IdentityConfig.store.account_creation_device_profiling == :enabled
    return unless user_session[:in_account_creation_flow]
    return unless user_session[:next_mfa_selection_choice] == nil
    return unless current_user
    DeviceProfilingResult.for_user(user_id: current_user.id, type: type)
  end
  
  def handle_failed_device_profiling(result)
    # Log the event
    analytics.device_profiling_restriction_enforced(
      client: result&.client,
      review_status: result&.review_status,
      reason: result&.reason
    )
    
    sign_out
    @failure_path =  device_profiling_failure_path
  end
end