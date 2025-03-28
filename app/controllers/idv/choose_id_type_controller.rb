# frozen_string_literal: true

module Idv
  class ChooseIdTypeController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern
    include Idv::ChooseIdTypeConcern

    before_action :redirect_if_passport_not_available

    def show
      analytics.idv_doc_auth_choose_id_type_visited(**analytics_arguments)
      render 'idv/shared/choose_id_type',
             locals: { form_url: idv_choose_id_type_path,
                       is_hybrid: false,
                       auto_check_value: auto_check_value },
             layout: true
    end

    def update
      clear_future_steps!

      @choose_id_type_form = Idv::ChooseIdTypeForm.new

      result = @choose_id_type_form.submit(choose_id_type_form_params)

      analytics.idv_doc_auth_choose_id_type_submitted(
        **analytics_arguments.merge(result.to_h)
          .merge({ chosen_id_type: }),
      )

      if result.success?
        set_passport_requested
        redirect_to next_step
      else
        redirect_to idv_choose_id_type_url
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
          if idv_session.document_capture_session_uuid
            DocumentCaptureSession.find_by(uuid: idv_session.document_capture_session_uuid)
              &.update!(passport_status: idv_session.passport_allowed ? 'allowed' : nil)
          end
        end,
      )
    end

    private

    def redirect_if_passport_not_available
      redirect_to idv_how_to_verify_url if !idv_session.passport_allowed
    end

    def next_step
      idv_document_capture_url
    end

    def analytics_arguments
      {
        step: 'choose_id_type',
        analytics_id: 'Doc Auth',
        flow_path: idv_session.flow_path,
      }
    end
  end
end
