# frozen_string_literal: true

module AccountRecovery
  # Placeholder for replacement MFA enrollment.
  #
  # Routes are committed so the flow's shape is visible, but replacement MFA
  # setup requires the recovery authorization and suspension ledger from later
  # phases of docs/adr/0001-account-preserving-mfa-recovery.md. Every action
  # fails closed with a not-found response until then.
  class NewMfaSetupController < ApplicationController
    def show
      render_not_found
    end

    def create
      render_not_found
    end
  end
end
