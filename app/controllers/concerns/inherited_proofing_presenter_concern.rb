module InheritedProofingPresenterConcern
  extend ActiveSupport::Concern

  included do
    before_action :init_presenter
  end

  private

  def init_presenter
    @presenter = Idv::InheritedProofing::InheritedProofingPresenter.new(
      service_provider: inherited_proofing_service_provider,
    )
  end
end
