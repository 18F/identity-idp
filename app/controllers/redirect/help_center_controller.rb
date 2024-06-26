# frozen_string_literal: true

module Redirect
  class HelpCenterController < RedirectController
    before_action :validate_help_center_article_params

    def show
      redirect_to_and_log MarketingSite.help_center_article_url(**article_params_with_provider)
    end

    private

    def validate_help_center_article_params
      return if MarketingSite.valid_help_center_article?(**article_params)
      redirect_to root_url
    end

    def article_params
      category, article, article_anchor = params.values_at(:category, :article, :article_anchor)
      { category:, article:, article_anchor: }
    end

    def article_params_with_provider
      params = article_params
      params[:partner] = current_sp&.agency&.name
      params[:partner_division] = current_sp&.integration&.name
      params
    end
  end
end
