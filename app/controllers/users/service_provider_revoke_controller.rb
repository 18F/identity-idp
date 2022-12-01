module Users
  class ServiceProviderRevokeController < ApplicationController
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
      analytics.sp_revoke_consent_revoked(issuer: @service_provider.issuer)

      redirect_to account_connected_accounts_path
    end

    private

    def load_identity!(service_provider)
      # mattw: The test for this calls the IdentityLinker and starts to become
      # a catch 22. Inclined to leave this as-is for the moment and get it in the next wave.
      current_user.identities.where(service_provider: service_provider.issuer).first!
    end
  end
end
