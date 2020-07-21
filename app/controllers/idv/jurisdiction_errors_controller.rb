module Idv
  class JurisdictionErrorsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def no_id; end
  end
end
