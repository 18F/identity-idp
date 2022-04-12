class Api::CompleteController < ActionController::Base

  def get_personal_key
    #verify_params = params.require(:verify).permit(:password,:details)

    #init_profile(verify_params[:password])
    # analytics.track_event(Analytics::IDV_PERSONAL_KEY_VISITED)
    # ProofingComponent.create_or_find_by(user: current_user).update(verified_at: Time.zone.now)
    # code = personal_key
    # # figure out how to get profile pending.
    # # profile_pending =
    # profile_pending = ''
    #
    render json: {personal_key: personal_key, profile_pending: profile_pending}, status: status
  end

  private

  def personal_key
    idv_session.personal_key || generate_personal_key
  end

  def generate_personal_key
    cacher = Pii::Cacher.new(current_user, user_session)
    idv_session.profile.encrypt_recovery_pii(cacher.fetch)
  end

  def init_profile(password)
    idv_session.create_profile_from_applicant_with_password(password)
    idv_session.cache_encrypted_pii(password)
    idv_session.complete_session

    if idv_session.phone_confirmed?
      event = create_user_event_with_disavowal(:account_verified)
      UserAlerts::AlertUserAboutAccountVerified.call(
        user: current_user,
        date_time: event.created_at,
        sp_name: decorated_session.sp_name,
        disavowal_token: event.disavowal_token,
      )
    end
  end
end
