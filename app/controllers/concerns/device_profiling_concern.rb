module DeviceProfilingConcern
  extend ActiveSupport::Concern

  def process_device_profiling_result
    return unless IdentityConfig.store.account_creation_device_profiling == :enabled
    return unless user_session[:in_account_creation_flow]
    return unless user_session[:next_mfa_selection_choice] == nil
    check_device_profiling_result(DeviceProfilingResult::PROFILING_TYPES[:account_creation])
  end
  
  def check_device_profiling_result(type)
    return unless current_user
    
    DeviceProfilingResult.for_user(user_id: current_user.id, type: type)
  end
  
  def handle_failed_device_profiling(result)
    result = DeviceProfilingResult.for_user(current_user.id).first
    
    # Log the event
    analytics.device_profiling_restriction_enforced(
      client: result&.client,
      review_status: result&.review_status,
      reason: result&.reason
    )
    
    sign_out
    @failure_path =  device_profiling_failure_path
  end
  
  # # Method to check if device profiling is still pending or has completed
  # def device_profiling_status(user)
  #   return :not_started unless session[:device_profiling_initiated_at]
    
  #   result = DeviceProfilingResult.for_user(user.id)
    
  #   if result
  #     result.success? ? :passed : :failed
  #   else
  #     # Check if we've been waiting too long
  #     initiated_at = session[:device_profiling_initiated_at]
  #     elapsed_time = Time.zone.now.to_i - initiated_at
      
  #     if elapsed_time > IdentityConfig.store.device_profiling_max_wait_seconds.to_i
  #       :timeout
  #     else
  #       :pending
  #     end
  #   end
  # end
end