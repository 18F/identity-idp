# frozen_string_literal: true

module Idv
  class AccountVerifiedEmailPresenter
    include Rails.application.routes.url_helpers

    attr_reader :profile, :url_options

    def initialize(profile:, url_options:)
      @profile = profile
      @url_options = url_options
    end

    def service_provider
      profile.initiating_service_provider
    end

    def show_cta?
      !service_provider || service_provider_post_idv_followup_url.present?
    end

    def sign_in_url
      url_params = {
        campaign_id:,
        issuer: service_provider&.issuer,
      }.compact_blank

      UriService.add_params(
        account_verified_sign_in_redirect_url,
        url_params,
      )
    end

    def displayed_sign_in_url
      service_provider_post_idv_followup_url || root_url
    end

    def service_provider_post_idv_followup_url
      sp_return_url_resolver.post_idv_followup_url if service_provider
    end

    def sp_name
      service_provider&.friendly_name || APP_NAME
    end

    private

    def campaign_id
      IdentityConfig.store.idv_account_verified_email_campaign_id
    end

    def sp_return_url_resolver
      SpReturnUrlResolver.new(service_provider:) if service_provider
    end
  end
end
