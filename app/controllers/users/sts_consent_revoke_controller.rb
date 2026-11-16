# frozen_string_literal: true

module Users
  # Revokes a user's STS (token exchange) consent, which stops an actor from
  # acting on the user's behalf for the consented target app.
  class StsConsentRevokeController < ApplicationController
    before_action :confirm_two_factor_authenticated

    rescue_from ActiveRecord::RecordNotFound do
      redirect_to account_connected_services_path
    end

    def show
      @consent = load_consent
      analytics.sts_revoke_consent_visited(
        target_issuer: @consent.target_app,
        actor_issuer: @consent.actor_app,
      )
    end

    def destroy
      consent = load_consent
      target_issuer = consent.target_app
      actor_issuer = consent.actor_app

      consent.update!(is_revoked: true)
      analytics.sts_revoke_consent_revoked(target_issuer:, actor_issuer:)

      redirect_to account_connected_services_path
    end

    private

    def load_consent
      current_user.connected_delegations.find(params[:id])
    end
  end
end
