# frozen_string_literal: true

module Accounts
  module ConnectedServices
    # Lets a user manage, per application, whether a connected broker may act on
    # their behalf there, and whether new applications they connect are enrolled
    # automatically. Each toggle is its own grant row (or the per-broker
    # auto-enroll setting) so there is never an "all" state to fight with.
    class TokenExchangeGrantsController < ApplicationController
      before_action :confirm_two_factor_authenticated
      before_action :validate_broker

      def update
        handled =
          case params[:grant_type]
          when 'target' then update_target
          when 'auto_enroll' then update_auto_enroll
          else false
          end
        return render_not_found unless handled

        redirect_to account_connected_services_path(anchor: "connected-app-#{broker_identity.id}")
      end

      private

      # @return [Boolean] whether the request was valid and applied
      def update_target
        target = ServiceProvider.active.find_by(issuer: params[:target_issuer])
        return false if target.blank? || target.issuer == broker.issuer
        return false unless target.accepts_delegation_from?(broker.issuer)
        return false unless linked_to?(target)

        if enabled?
          TokenExchangeGrant.grant_one!(
            user: current_user, broker_issuer: broker.issuer, target_issuer: target.issuer,
          )
        else
          TokenExchangeGrant.revoke!(
            user: current_user, broker_issuer: broker.issuer, target_issuer: target.issuer,
          )
        end

        analytics.token_exchange_grant_toggled(
          issuer: broker.issuer, target_issuer: target.issuer, enabled: enabled?,
        )
        true
      end

      def update_auto_enroll
        setting = TokenExchangeBrokerSetting.for(user: current_user, broker_issuer: broker.issuer)
        enabled? ? setting.enable_auto_enroll! : setting.disable_auto_enroll!

        analytics.token_exchange_auto_enroll_toggled(issuer: broker.issuer, enabled: enabled?)
        true
      end

      def enabled?
        ActiveModel::Type::Boolean.new.cast(params[:enabled]) == true
      end

      def linked_to?(target)
        current_user.connected_apps.exists?(service_provider: target.issuer)
      end

      def validate_broker
        render_not_found if broker_identity.blank? || broker.blank? ||
                            !broker.delegation_service_provider?
      end

      def broker_identity
        return @broker_identity if defined?(@broker_identity)
        @broker_identity = current_user.connected_apps.find_by(id: params[:identity_id])
      end

      def broker
        broker_identity&.service_provider_record
      end
    end
  end
end
