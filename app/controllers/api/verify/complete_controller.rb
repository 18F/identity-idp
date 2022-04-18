class Api::Verify::CompleteController < ApplicationController
  include IdvSession
  before_action :confirm_two_factor_authenticated
  before_action :confirm_idv_vendor_session_started
  before_action :confirm_profile_has_been_created


  def get_personal_key
    #verify_params = params.require(:verify).permit(:password,:details)

    # Create profile Maker with Pii using the password
    # Cash temporarly to session

    # Generate Personal Key
    analytics.track_event(Analytics::IDV_PERSONAL_KEY_VISITED)
    add_proofing_component
    render json: {personal_key: personal_key, profile_pending: {}}
  end

  private

  def personal_key
    idv_session.personal_key || generate_personal_key
  end

  def generate_personal_key
    cacher = Pii::Cacher.new(current_user, user_session)
    idv_session.profile.encrypt_recovery_pii(cacher.fetch)
  end

  def add_proofing_component
    ProofingComponent.create_or_find_by(user: current_user).update(verified_at: Time.zone.now)
  end

  def confirm_profile_has_been_created
    render json: { error: 'User credentials not found'.to_json, status: 401 } if idv_session.profile.blank?
  end

end
