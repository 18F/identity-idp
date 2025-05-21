module DeviceProfilingConcern
  extend ActiveSupport::Concern
  
  private
  
  def check_device_profiling_result
    return unless current_user
    
    # Check if the user has failed device profiling
    if DeviceProfilingResult.failed?(current_user.id)
      handle_failed_device_profiling
      return false
    end
    
    true
  end
  
  def handle_failed_device_profiling
    result = DeviceProfilingResult.for_user(current_user.id)
    
    # Log the event
    analytics.device_profiling_restriction_enforced(
      client: result&.client,
      review_status: result&.review_status,
      reason: result&.reason
    )
    
    if result&.review_status == 'reject'
      # For automatic rejections, sign the user out and redirect
      sign_out
      redirect_to device_profiling_failure_path
    else
      # For other failures (like "review"), potentially handle differently
      # For example, allow limited access but show a warning
      flash.now[:warning] = t('device_profiling.warning.under_review')
    end
  end
  
  # Method to check if device profiling is still pending or has completed
  def device_profiling_status(user)
    return :not_started unless session[:device_profiling_initiated_at]
    
    result = DeviceProfilingResult.for_user(user.id)
    
    if result
      result.success? ? :passed : :failed
    else
      # Check if we've been waiting too long
      initiated_at = session[:device_profiling_initiated_at]
      elapsed_time = Time.zone.now.to_i - initiated_at
      
      if elapsed_time > IdentityConfig.store.device_profiling_max_wait_seconds.to_i
        :timeout
      else
        :pending
      end
    end
  end
end