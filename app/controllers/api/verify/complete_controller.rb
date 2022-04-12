class Api::Verify::CompleteController < ApplicationController

  def get_personal_key
    #verify_params = params.require(:verify).permit(:password,:details)

    # Create profile Maker with Pii using the password
    # Cash temporarly to session
    #

    # Generate Personal Key
    analytics.track_event(Analytics::IDV_PERSONAL_KEY_VISITED)
    add_proofing_component
    render json: {personal_key: {}, profile_pending: {}}
  end

  private

  def personal_key
    idv_session.personal_key || generate_personal_key
  end


  def add_proofing_component
    ProofingComponent.create_or_find_by(user: current_user).update(verified_at: Time.zone.now)
  end

end
