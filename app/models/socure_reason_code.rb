# frozen_string_literal: true

class SocureReasonCode < ApplicationRecord
  UNKNOWN_REASON_CODE = '[unknown]'
  def self.active
    where(deactivated_at: nil)
  end

  def self.with_definitions(reason_codes)
    known_codes = SocureReasonCode.where(
      code: reason_codes,
    ).pluck(:code, :description).to_h
    reason_codes.index_with { |code| known_codes[code] || UNKNOWN_REASON_CODE }
  end
end
