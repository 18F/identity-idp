module Verify
  class UspsController < ApplicationController
    include IdvStepConcern

    before_action :confirm_step_needed

    def index
      @applicant = idv_session.normalized_applicant_params
    end

    def create
      idv_session.address_verification_mechanism = :usps
      redirect_to verify_review_url
    end

    private

    def confirm_step_needed
      redirect_to verify_review_path if idv_session.address_mechanism_chosen?
    end
  end
end
