# frozen_string_literal: true

module Redirect
  class PartnerExitController < Redirect::ReturnToSpController
    before_action :validate_sp_exists

    def show
      @redirect_url = sp_return_url_resolver.return_to_sp_url
    end
  end
end
