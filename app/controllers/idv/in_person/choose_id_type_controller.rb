# frozen_string_literal: true

class Idv::InPerson::ChooseIdTypeController < ApplicationController
  include Idv::AvailabilityConcern
  include IdvStepConcern
  include Idv::ChooseIdTypeConcern

  before_action :confirm_step_allowed

  def show
    analytics.idv_in_person_proofing_choose_id_type_visited(**analytics_arguments)

    render 'idv/shared/choose_id_type',
           locals: locals_attrs(
             analytics:,
             presenter: Idv::InPerson::ChooseIdTypePresenter.new,
             form_submit_url: idv_in_person_choose_id_type_url,
           ),
           layout: true
  end

  def update
    clear_future_steps!

    form = Idv::ChooseIdTypeForm.new
    result = form.submit(allowed_params)

    analytics.idv_in_person_proofing_choose_id_type_submitted(
      **analytics_arguments
        .merge(**result.to_h)
        .merge(chosen_id_type: form.chosen_id_type),
    )

    if result.success?
      set_chosen_id_type
      redirect_to chosen_id_type_url(form.chosen_id_type)
    else
      redirect_to idv_in_person_choose_id_type_url
    end
  end

  def self.step_info
    Idv::StepInfo.new(
      key: :ipp_choose_id_type,
      controller: self,
      next_steps: [:ipp_state_id, :ipp_passport],
      preconditions: ->(idv_session:, user:) {
        idv_session.in_person_passports_allowed? && user.has_establishing_in_person_enrollment?
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

  def analytics_arguments
    {
      flow_path: idv_session.flow_path,
      step: 'choose_id_type',
      analytics_id: 'In Person Proofing',
    }.merge(ab_test_analytics_buckets)
      .merge(extra_analytics_properties)
  end

  def allowed_params
    choose_id_type_form_params
  end

  def chosen_id_type_url(type)
    case type
    when 'passport'
      idv_in_person_passport_url
    when 'drivers_license'
      idv_in_person_state_id_url
    end
  end

  def set_chosen_id_type
    set_passport_requested
  end
end
