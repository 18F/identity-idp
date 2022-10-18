class InheritedProofingJob < ApplicationJob
  include JobHelpers::StaleJobHelper
  include Idv::InheritedProofing::ServiceProviderServices

  queue_as :default

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  def perform(service_provider, service_provider_data, uuid)
    document_capture_session = DocumentCaptureSession.find_by(uuid: uuid)

    payload_hash = Idv::InheritedProofing::ServiceProviderServiceFactory.execute(
      service_provider: service_provider,
      service_provider_data: service_provider_data,
    )

    raise_stale_job! if stale_job?(enqueued_at)

    document_capture_session.store_proofing_result(payload_hash)
  end
end
