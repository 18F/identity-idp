# frozen_string_literal: true

module Redirect
  class MarketingSiteController < RedirectController
    def show
      redirect_to_and_log(MarketingSite.base_url)
    end
  end
end
