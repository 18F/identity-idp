module IdvSession
  extend ActiveSupport::Concern

  def confirm_idv_session_started
    redirect_to idv_session_url unless idv_session.params.present?
  end

  def confirm_idv_attempts_allowed
    if idv_attempter.exceeded?
      flash[:error] = t('idv.errors.hardfail')
      redirect_to idv_fail_url
    elsif idv_attempter.reset_attempts?
      idv_attempter.reset
    end
  end

  def confirm_idv_needed
    redirect_to idv_activated_url if current_user.active_profile.present?
  end

  def confirm_idv_vendor_session_started
    redirect_to idv_session_path unless idv_session.proofing_started?
  end

  def idv_session
    @_idv_session ||= Idv::Session.new(user_session, current_user)
  end

  def idv_vendor
    @_idv_vendor ||= Idv::Vendor.new
  end

  def idv_attempter
    @_idv_attempter ||= Idv::Attempter.new(current_user)
  end

  def idv_agent
    @_agent ||= Proofer::Agent.new(
      applicant: idv_session.applicant,
      vendor: (idv_session.vendor || idv_vendor.pick),
      kbv: FeatureManagement.proofing_requires_kbv?
    )
  end

  def init_questions_and_profile(resolution)
    idv_session.resolution = resolution
    idv_session.question_number = 0
    idv_session.profile_from_applicant(idv_session.applicant, password)
  end
end
