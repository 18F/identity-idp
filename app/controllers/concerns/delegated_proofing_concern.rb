module DelegatedProofingConcern
  extend ActiveSupport::Concern

  def delegated_proofing_session?
    ServiceProvider.from_issuer(sp_session[:issuer]).supports_delegated_proofing?
  end
end
