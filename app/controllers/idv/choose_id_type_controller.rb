# frozen_string_literal: true

module Idv
  class ChooseIdTypeController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :redirect_if_passport_not_available

    def show
    end

    def update
      clear_future_steps!

      @choose_id_type_form = Idv::ChooseIdTypeForm.new

      result = @choose_id_type_form.submit(choose_id_type_form_params)

      if result.success?
        set_passport_requested
        redirect_to next_step
      else
        render :show
      end
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :choose_id_type,
        controller: self,
        next_steps: [:document_capture],
        preconditions: ->(idv_session:, user:) {
          idv_session.flow_path == 'standard' &&
            idv_session.passport_allowed == true
        },
        undo_step: ->(idv_session:, user:) do
        end,
      )
    end

    private

    def redirect_if_passport_not_available
      redirect_to idv_hybrid_handoff_url if !idv_session.passport_allowed
    end

    def set_passport_requested
      if choose_id_type_form_params[:choose_id_type_preference] == 'passport'
        idv_session.passport_requested = true
      else
        idv_session.passport_requested = false
      end
    end

    def next_step
      if idv_session.passport_requested
        # page is not created yet redirect to in person for now
        idv_in_person_url
      else
        idv_document_capture_url
      end
    end

    def choose_id_type_form_params
      params.require(:doc_auth).permit(:choose_id_type_preference)
    end
  end
end
