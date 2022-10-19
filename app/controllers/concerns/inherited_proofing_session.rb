module InheritedProofingSession
  extend ActiveSupport::Concern
  include InheritedProofingConcern

  private

  def destroy_inherited_proofing
    inherited_proofing_clear_session
    inherited_proofing_log_analytics
  end

  def inherited_proofing_clear_session
    user_session['idv/inherited_proofing'] = {}
  end

  # LG-7128: Implement Inherited Proofing analytics here.
  def inherited_proofing_log_analytics
    # analytics.inherited_proofing_start_over(
    #   step: location_params[:step],
    #   location: location_params[:location],
    # )
  end
end
