module IdvSession
  extend ActiveSupport::Concern

  def confirm_idv_session_started
    redirect_to idv_session_url unless idv_session.params.present?
  end

  def confirm_idv_attempts_allowed
    attempter = idv_session.attempter
    if attempter.exceeded?
      flash[:error] = t('idv.errors.hardfail')
      redirect_to idv_fail_url
    elsif attempter.reset_attempts?
      idv_session.attempts = 0
    end
  end

  def confirm_idv_needed
    redirect_to idv_activated_url if current_user.active_profile.present?
  end

  def idv_session
    @_idv_session ||= Idv::Session.new(user_session, current_user)
  end

  def idv_vendor
    @_idv_vendor ||= Idv::Vendor.new
  end
end
