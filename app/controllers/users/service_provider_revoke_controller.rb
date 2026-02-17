# frozen_string_literal: true

module Users
  class ServiceProviderRevokeController < ApplicationController
    include OneAccountConcern
    before_action :confirm_two_factor_authenticated

    rescue_from ActiveRecord::RecordNotFound do
      redirect_to account_connected_accounts_path
    end

    def show
      @service_provider = ServiceProvider.find(params[:sp_id])
      load_identity!(@service_provider)
      analytics.sp_revoke_consent_visited(issuer: @service_provider.issuer)
    end

    def destroy
      @service_provider = ServiceProvider.find(params[:sp_id])
      identity = load_identity!(@service_provider)

      RevokeServiceProviderConsent.new(identity).call
      process_one_account_self_service_if_applicable(source: :account_management_unlinked_from_sp)
      notify_user_of_revoked_consent
      analytics.sp_revoke_consent_revoked(issuer: @service_provider.issuer)

      redirect_to account_connected_accounts_path
    end

    private

    def load_identity!(service_provider)
      current_user.identities.where(service_provider: service_provider.issuer).first!
    end

    def notify_user_of_revoked_consent
      _event, disavowal_token = create_user_event_with_disavowal(:sp_user_consent_revoked)
      current_user.email_addresses.each do |email_address_record|
        UserMailer.with(user: current_user, email_address: email_address_record)
          .account_disconnected_from_sp(sp_name: @service_provider.friendly_name, disavowal_token:)
          .deliver_now_or_later
      end
    end
  end
end
