module Redirect
  class ContactController < RedirectController
    def show
      redirect_to_and_log(
        IdentityConfig.store.idv_contact_url,
        tracker_method: analytics.method(:contact_redirect),
      )
    end
  end
end
