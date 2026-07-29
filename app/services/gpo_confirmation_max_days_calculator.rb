# frozen_string_literal: true

class GpoConfirmationMaxDaysCalculator
  def self.max_days_for_state(state)
    if Idp::Constants::CONTIGUOUS_US_STATE_CODES.include?(state)
      IdentityConfig.store.usps_confirmation_max_days_contiguous_states
    else
      IdentityConfig.store.usps_confirmation_max_days
    end
  end
end
