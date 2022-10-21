module InheritedProofing404Concern
  extend ActiveSupport::Concern

  included do
    before_action :render_404_if_disabled
  end

  private

  def render_404_if_disabled
    render_not_found unless IdentityConfig.store.inherited_proofing_enabled
  end
end
