# frozen_string_literal: true

module Idv
  class ChooseIdTypeController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern

    def show
    end

    def update
      clear_future_steps!

      @choose_id_type_form = Idv::ChooseIdTypeForm.new

      result = @choose_id_type_form.submit(choose_id_type_form_params)

      if result.success?
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
          idv_session.flow_path == 'standard'
        },
        undo_step: ->(idv_session:, user:) do
        end,
      )
    end

    private

    def chosen_id_type
      @choose_id_type_form.chosen_id_type.to_sym
    end

    def next_step
      if chosen_id_type == :drivers_license
        idv_document_capture_url
      elsif chosen_id_type == :passport
        # page is not created yet redirect to in person for now
        idv_in_person_url
      end
    end

    def choose_id_type_form_params
      params.require(:doc_auth).permit(:choose_id_type_preference) 
    end
  end
end
