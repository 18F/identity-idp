class Api::Verify::CompleteController < ActionController::Base

  def get_personal_key
    #verify_params = params.require(:verify).permit(:password,:details)

    # Create profile Maker with Pii using the password
    # Cash temporarly to session
    # Generate Personal Key
    render json: {personal_key: {}, profile_pending: {}}
  end

  private

  def personal_key
    idv_session.personal_key || generate_personal_key
  end

  def generate_personal_key
    cacher = Pii::Cacher.new(current_user, user_session)
    idv_session.profile.encrypt_recovery_pii(cacher.fetch)
  end

end
