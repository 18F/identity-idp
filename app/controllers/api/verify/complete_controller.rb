class Api::Verify::CompleteController < Api::BaseController
  before_action :confirm_two_factor_authenticated_for_api

  def create
    verify_params = params.require(:verify).permit(:password, :details)
    result = Api::ProfileCreationForm.new.submit(verify_params)
    analytics.track_event(Analytics::IDV_PERSONAL_KEY_VISITED, result.to_h)

    if result.success?
      add_proofing_component
      render json: { personal_key: generate_personal_key,
                     profile_pending: result.extra[:profile_pending],
                     status: 'error' }
    else
      render json: { error: result.error, status: 'error' }
    end
  end

  private

  def add_proofing_component
    ProofingComponent.create_or_find_by(user: current_user).update(verified_at: Time.zone.now)
  end

end
