module Redirect
  class HelpCenterController < RedirectController
    before_action :validate_help_center_article_params

    def show
      redirect_to_and_log MarketingSite.help_center_article_url(**article_params)
    end

    private

    def validate_help_center_article_params
      return if MarketingSite.valid_help_center_article?(**article_params)
      redirect_to root_url
    end

    def article_params
      begin
        category, article = params.require([:category, :article])
      rescue ActionController::ParameterMissing; end

      { category:, article:, article_anchor: params[:article_anchor] }
    end
  end
end
