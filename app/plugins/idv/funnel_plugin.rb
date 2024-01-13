module Idv
  # Responsible for updating the doc auth funnel in response to actions in the IdP.
  class FunnelPlugin < BasePlugin
    on_step_completed :request_letter do |user:, sp:, **rest|
      Funnel::DocAuth::RegisterStep.new(user.id, sp&.issuer).call(
        :usps_address, :view, true
      )
    end

    on_step_completed :request_letter do |user:, sp:, **rest|
      Funnel::DocAuth::RegisterStep.new(user.id, sp&.issuer).
        call(:usps_letter_sent, :update, true)
    end
  end
end
