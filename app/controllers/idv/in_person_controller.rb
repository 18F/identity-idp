# frozen_string_literal: true

module Idv
  class InPersonController < ApplicationController
    include Idv::AvailabilityConcern
    include RenderConditionConcern

    check_or_render_not_found -> { InPersonConfig.enabled_for_issuer?(current_sp&.issuer) }

    before_action :confirm_two_factor_authenticated
    before_action :redirect_unless_enrollment
    before_action :initialize_in_person_session
    before_action :set_usps_form_presenter

    def index
      redirect_to idv_in_person_state_id_url
    end

    def update
      redirect_to idv_in_person_state_id_url
    end

    private

    def redirect_unless_enrollment
      redirect_to idv_url unless current_user.establishing_in_person_enrollment
    end

    def initialize_in_person_session
      user_session['idv/in_person'] ||= { pii_from_user: { uuid: current_user.uuid } }
      # binding.pry
    end

    def set_usps_form_presenter
      @presenter = Idv::InPerson::UspsFormPresenter.new
    end
  end
end
