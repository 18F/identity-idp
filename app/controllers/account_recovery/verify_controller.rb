# frozen_string_literal: true

module AccountRecovery
  # Placeholder for recovery link redemption.
  #
  # Routes are committed so the flow's shape is visible, but link verification
  # is Phase 3 of docs/adr/0001-account-preserving-mfa-recovery.md and is inert
  # until then. Every action fails closed with a not-found response.
  class VerifyController < ApplicationController
    def show
      render_not_found
    end

    def create
      render_not_found
    end
  end
end
