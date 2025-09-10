# frozen_string_literal: true

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
      measure_one_account_self_service_if_applicable
      analytics.sp_revoke_consent_revoked(issuer: @service_provider.issuer)

      redirect_to account_connected_accounts_path
    end

    private

    def load_identity!(service_provider)
      current_user.identities.where(service_provider: service_provider.issuer).first!
    end

    def measure_one_account_self_service_if_applicable
      return unless user_has_ial2_facial_match_profile?
      set = DuplicateProfileSet.find_by_profile(profile_id: current_user&.active_profile)
      return unless set

      analytics.one_account_self_service(
        source: :account_management_delete,
        service_provider: set.service_provider,
        associated_profiles_count: set.profile_ids.exclude?(current_user.active_profile.id).count,
        dupe_profile_set_id: set.id,
      )
    end
  end
end
