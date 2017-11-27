module Verify
  class AddressController < ApplicationController
    include IdvStepConcern

    before_action :confirm_step_needed

    def index; end

    private

    def confirm_step_needed
      redirect_to verify_review_url if idv_session.address_mechanism_chosen?
    end
  end
end
