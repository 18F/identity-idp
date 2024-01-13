module Idv
  class ProofingComponentPlugin < BasePlugin
    on_step_completed :request_letter do |user:, **rest|
      ProofingComponent.find_or_create_by(user: user).update(address_check: 'gpo_letter')
    end
  end
end
