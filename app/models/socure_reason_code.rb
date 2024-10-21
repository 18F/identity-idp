# frozen_string_literal: true

class SocureReasonCode < ApplicationRecord
  def self.active
    where(deactivated_at: nil)
  end
end
