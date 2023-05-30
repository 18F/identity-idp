module IdvSession
  extend ActiveSupport::Concern
  include EffectiveUser

  included do
    before_action :redirect_unless_effective_user
    before_action :redirect_if_sp_context_needed
  end

  def confirm_idv_needed
    return if effective_user.active_profile.blank? ||
              decorated_session.requested_more_recent_verification? ||
              effective_user.reproof_for_irs?(service_provider: current_sp)

    redirect_to idv_activated_url
  end

  def hybrid_session?
    session[:doc_capture_user_id].present?
  end

  def confirm_phone_or_address_confirmed
    return if flash[:allow_confirmations_continue]
    return if idv_session.address_confirmed? || idv_session.phone_confirmed?

    redirect_to idv_doc_auth_url
  end

  def idv_session
    @idv_session ||= Idv::Session.new(
      user_session: user_session,
      current_user: effective_user,
      service_provider: current_sp,
    )
  end

  def redirect_unless_effective_user
    redirect_to root_url if !effective_user
  end

  def redirect_if_sp_context_needed
    return if sp_from_sp_session.present?
    return unless IdentityConfig.store.idv_sp_required
    return if effective_user.profiles.any?

    redirect_to account_url
  end
end
