# frozen_string_literal: true

class SocureReasonCodeDownloadJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :low

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  def perform
    return unless IdentityConfig.store.idv_socure_reason_code_download_enabled

    result = Proofing::Socure::ReasonCodes::Importer.new.synchronize
    analytics.idv_socure_reason_code_download(**result.to_h)
  end

  def analytics
    Analytics.new(
      user: AnonymousUser.new,
      request: nil,
      sp: service_provider_issuer,
      session: {},
    )
  end
end
