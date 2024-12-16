# frozen_string_literal: true

module Idv
  class AccountVerifiedCtaVisitedController < ApplicationController
    before_action :disable_caching
    before_action :confirm_redirect_requestable

    def show
      redirect_to(redirect_url, allow_other_host: true)
      analytics.idv_account_verified_cta_visited(campaign_id:, issuer:)
    end

    private

    def confirm_redirect_requestable
      return if redirect_url.present?

      render_bad_request
    end

    def redirect_url
      if issuer.blank?
        root_url
      else
        sp_return_url_resolver&.post_idv_follow_up_url ||
          sp_return_url_resolver&.return_to_sp_url
      end
    end

    def issuer
      valid_params[:issuer]
    end

    def campaign_id
      valid_params[:campaign_id]
    end

    def valid_params
      params.permit(:campaign_id, :issuer)
    end

    def service_provider
      ServiceProvider.find_by(issuer:) if issuer.present?
    end

    def sp_return_url_resolver
      SpReturnUrlResolver.new(service_provider:) if service_provider
    end
  end
end
