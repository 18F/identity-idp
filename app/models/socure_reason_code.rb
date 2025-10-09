# frozen_string_literal: true

class SocureReasonCode < ApplicationRecord
  def self.active
    where(deactivated_at: nil)
  end

  def self.reason_codes_with_defnitions(reason_codes)
    known_codes = SocureReasonCode.where(
      code: reason_codes,
    ).pluck(:code, :description).to_h
    reason_codes.index_with { |code| known_codes[code] || UNKNOWN_REASON_CODE }
  end
end
