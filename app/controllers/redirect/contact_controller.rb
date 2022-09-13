module Redirect
  class ContactController < RedirectController
    def show
      redirect_to_and_log IdentityConfig.store.idv_contact_url
    end
  end
end
