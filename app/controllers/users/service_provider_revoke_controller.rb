module Users
  class ServiceProviderRevokeController < ApplicationController
    before_action :confirm_two_factor_authenticated

    rescue_from ActiveRecord::RecordNotFound do
      redirect_to account_url
    end

    def show
      @service_provider = ServiceProvider.find(params[:sp_id])
      load_identity!(@service_provider)
    end

    def destroy
      @service_provider = ServiceProvider.find(params[:sp_id])
      identity = load_identity!(@service_provider)

      

      redirect_to account_url
    end

    private

    def load_identity!(service_provider)
      current_user.identities.where(service_provider: service_provider.issuer).first!
    end
  end
end
