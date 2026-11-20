# frozen_string_literal: true

module AccountRecoverySuspendable
  extend ActiveSupport::Concern

  included do
    scope :available_for_authentication, -> { where(account_recovery_request_id: nil) }
  end

  def suspended_for_account_recovery?
    account_recovery_request_id.present?
  end
end
