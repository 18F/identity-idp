# frozen_string_literal: true

module Idv
  class EnterDobSsnController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include Idv::StepIndicatorConcern

    def new
      @ssn_presenter = Idv::SsnPresenter.new(
        sp_name: decorated_sp_session.sp_name,
        ssn_form: Idv::SsnFormatForm.new(idv_session.ssn),
        step_indicator_steps: step_indicator_steps,
      )
    end

    def create
    end
  end
end
