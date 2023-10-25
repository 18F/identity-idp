# frozen_string_literal: true

module Redirect
  class ContactController < RedirectController
    def show
      redirect_to_and_log(
        MarketingSite.contact_url,
        tracker_method: analytics.method(:contact_redirect),
      )
    end
  end
end
