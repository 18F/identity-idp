module IdvSession
  extend ActiveSupport::Concern

  def confirm_idv_session_started
    return if current_user.decorate.needs_profile_usps_verification?
    redirect_to idv_session_url if idv_session.params.blank?
  end

  def confirm_idv_attempts_allowed
    if idv_attempter.exceeded?
      flash[:error] = t('idv.errors.hardfail')
      analytics.track_event(Analytics::IDV_MAX_ATTEMPTS_EXCEEDED, request_path: request.path)
      redirect_to idv_fail_url
    elsif idv_attempter.reset_attempts?
      idv_attempter.reset
    end
  end

  def confirm_idv_needed
    redirect_to idv_activated_url if current_user.active_profile.present?
  end

  def confirm_idv_vendor_session_started
    return if flash[:allow_confirmations_continue]
    redirect_to idv_session_url unless idv_session.proofing_started?
  end

  def idv_session
    @_idv_session ||= Idv::Session.new(
      user_session: user_session,
      current_user: current_user,
      issuer: sp_session[:issuer]
    )
  end

  def idv_attempter
    @_idv_attempter ||= Idv::Attempter.new(current_user)
  end

  def vendor_validator_result
    return timed_out_vendor_error if vendor_result_timed_out?

    VendorValidatorResultStorage.new.load(idv_session.async_result_id)
  end

  def vendor_result_timed_out?
    started_at = idv_session.async_result_started_at
    return false if started_at.blank?

    expiration = started_at + Figaro.env.async_job_refresh_max_wait_seconds.to_i
    Time.zone.now.to_i >= expiration
  end

  def timed_out_vendor_error
    Idv::VendorResult.new(
      success: false,
      errors: { timed_out: ['Timed out waiting for vendor response'] },
      timed_out: true
    )
  end

  def refresh_if_not_ready
    return if vendor_validator_result.present?

    render 'shared/refresh'
  end
end
