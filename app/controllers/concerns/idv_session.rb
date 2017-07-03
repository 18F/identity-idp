module IdvSession
  extend ActiveSupport::Concern

  def confirm_idv_session_started
    return if current_user.decorate.needs_profile_usps_verification?
    redirect_to verify_session_url if idv_session.params.blank?
  end

  def confirm_idv_attempts_allowed
    if idv_attempter.exceeded?
      flash[:error] = t('idv.errors.hardfail')
      analytics.track_event(Analytics::IDV_MAX_ATTEMPTS_EXCEEDED, request_path: request.path)
      redirect_to verify_fail_url
    elsif idv_attempter.reset_attempts?
      idv_attempter.reset
    end
  end

  def confirm_idv_needed
    redirect_to verify_activated_url if current_user.active_profile.present?
  end

  def confirm_idv_vendor_session_started
    return if flash[:allow_confirmations_continue]
    redirect_to verify_session_path unless idv_session.proofing_started?
  end

  def idv_session
    @_idv_session ||= Idv::Session.new(
      user_session: user_session,
      current_user: current_user,
      issuer: sp_session[:issuer]
    )
  end

  def idv_vendor
    @_idv_vendor ||= Idv::Vendor.new
  end

  def idv_attempter
    @_idv_attempter ||= Idv::Attempter.new(current_user)
  end

  def vendor_validator_result
    VendorValidatorResultStorage.new.load(idv_session.async_result_id)
  end
end
