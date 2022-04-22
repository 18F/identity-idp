class Api::Verify::CompleteController < Api::BaseController
  before_action :confirm_two_factor_authenticated_for_api

  def create
    result = Api::ProfileCreationForm.new(
      user_password: verify_params[:password],
      user_bundle: verify_params[:details],
      user_session: user_session,
      service_provider: current_sp,
    ).submit
    analytics.track_event(Analytics::IDV_PERSONAL_KEY_VISITED, result.to_h)

    if result.success?
      user = User.find_by(uuid: result.extra[:user_uuid])
      add_proofing_component(user)
      render json: {
        personal_key: result.extra[:personal_key],
        profile_pending: result.extra[:profile_pending],
        status: SUCCESS,
      }
    else
      render json: { error: result.errors, status: ERROR }
    end
  end

  private

  def verify_params
    params.permit(:password, :details)
  end

  def add_proofing_component(user)
    ProofingComponent.create_or_find_by(user: user).update(verified_at: Time.zone.now)
  end
end
