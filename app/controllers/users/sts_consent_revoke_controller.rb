# frozen_string_literal: true

module Users
  # Revokes a user's STS (token exchange) consent, which stops a broker from
  # acting on the user's behalf for the consented target app.
  class StsConsentRevokeController < ApplicationController
    before_action :confirm_two_factor_authenticated

    rescue_from ActiveRecord::RecordNotFound do
      redirect_to account_connected_services_path
    end

    def show
      @consent = load_consent!
      analytics.sts_revoke_consent_visited(target_app: @consent.target_app)
    end

    def destroy
      consent = load_consent!
      target_app = consent.target_app

      consent.destroy!
      analytics.sts_revoke_consent_revoked(target_app:)

      redirect_to account_connected_services_path
    end

    private

    def load_consent!
      current_user.connected_delegations.find(params[:id])
    end
  end
end
