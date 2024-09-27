# frozen_string_literal: true

module Idv
  class AccountVerifiedEmailPresenter
    # we'll prolly want this
    include Rails.application.routes.url_helpers

    attr_reader :profile

    def initialize(profile:)
      @profile = profile
    end

    def service_provider
      profile.initiating_service_provider
    end

    # Our logic is slightly different than in VerificationResultsEmailPresenter.
    # We'll show the CTA section as long as there's an SP at all, and just
    # conditionalize the URL.
    def show_cta?
      !service_provider || service_provider_homepage_url.present?
    end

    # copypasta
    def sign_in_url
      service_provider_homepage_url || root_url
    end

    # copypasta
    def service_provider_homepage_url
      sp_return_url_resolver.homepage_url if service_provider
    end

    # How do they handle this in the other one?
    def sp_name
      service_provider.friendly_name || APP_NAME
    end

    def url_options
      {}
    end

    private

    # copypasta
    def sp_return_url_resolver
      SpReturnUrlResolver.new(service_provider: service_provider)
    end

    # we want to handle:
    # - no SP at all
    # - SP, but no URL
    # - SP with URL (ideal case)
  end
end
