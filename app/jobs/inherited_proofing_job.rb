class InheritedProofingJob < ApplicationJob
  include InheritedProofingConcern
  include Idv::Steps::InheritedProofing::UserPiiManagable

  queue_as :default

  def perform(flow_session, result_id)
    @flow_session = flow_session
    inherited_proofing_save_user_pii_to_session!
    inherited_proofing_form_response
  end
end