# frozen_string_literal: true

module Accounts
  module ConnectedServices
    # Lets a user manage, per application, whether a connected service provider may act on their
    # behalf there. Each toggle reads and writes the same approval row the consent screen uses.
    class TokenExchangeGrantsController < ApplicationController
      before_action :confirm_two_factor_authenticated
      before_action :validate_service_provider

      def update
        return render_not_found unless update_application

        redirect_to account_connected_services_path(
          anchor: "connected-app-#{service_provider_identity.id}",
        )
      end

      private

      # Applies the toggle for one application. The application must be registered, accept this
      # service provider, not be the service provider itself, and be one the user has connected
      # to; anything else is refused as not found so nothing is learned about the registry here.
      # @return [Boolean] whether the request was valid and applied
      def update_application
        application = ServiceProvider.active.find_by(issuer: params[:application_issuer])
        return false if application.blank? || application.issuer == service_provider.issuer
        return false unless application.accepts_delegation_from?(service_provider.issuer)
        return false unless connected_to?(application)

        if enabled?
          # Approving from the account page is always remembered for the maximum period.
          TokenExchangeGrant.approve!(
            user: current_user, service_provider:, application:,
            source: 'account_page', remember: true
          )
        else
          TokenExchangeGrant.revoke_for!(
            user: current_user, service_provider_issuer: service_provider.issuer, application:,
            reason: 'user_revoked'
          )
        end

        analytics.delegation_grant_toggled(
          issuer: service_provider.issuer, application_issuer: application.issuer,
          enabled: enabled?
        )
        true
      end

      def enabled?
        ActiveModel::Type::Boolean.new.cast(params[:enabled]) == true
      end

      def connected_to?(application)
        current_user.connected_apps.exists?(service_provider: application.issuer)
      end

      def validate_service_provider
        render_not_found if service_provider_identity.blank? || service_provider.blank? ||
                            !service_provider.delegation_service_provider?
      end

      def service_provider_identity
        return @service_provider_identity if defined?(@service_provider_identity)

        @service_provider_identity = current_user.connected_apps.find_by(id: params[:identity_id])
      end

      def service_provider
        service_provider_identity&.service_provider_record
      end
    end
  end
end
