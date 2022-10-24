class InheritedProofingJob < ApplicationJob
  include Idv::InheritedProofing::ServiceProviderServices
  include Idv::InheritedProofing::ServiceProviderForms
  include JobHelpers::StaleJobHelper

  queue_as :default

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  def perform(service_provider, service_provider_data, uuid)
    document_capture_session = DocumentCaptureSession.find_by(uuid: uuid)

    payload_hash = inherited_proofing_service_for(
      service_provider,
      service_provider_data: service_provider_data,
    ).execute

    raise_stale_job! if stale_job?(enqueued_at)

    document_capture_session.store_proofing_result(payload_hash)
  end
end
