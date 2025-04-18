# frozen_string_literal: true

class Idv::InPerson::ChooseIdTypeController < ApplicationController
  include Idv::AvailabilityConcern
  include IdvStepConcern

  before_action :confirm_step_allowed

  def show
    analytics.idv_in_person_proofing_choose_id_type_visited(**analytics_arguments)
    render 'idv/shared/choose_id_type',
           locals: {
             presenter: Idv::InPerson::ChooseIdTypePresenter.new,
             auto_check_value: '',
           },
           layout: true
  end

  def update
  end

  def self.step_info
    Idv::StepInfo.new(
      key: :ipp_choose_id_type,
      controller: self,
      next_steps: [],
      preconditions: ->(idv_session:, user:) {
        idv_session.in_person_passports_allowed? && user.has_establishing_in_person_enrollment?
      },
      undo_step: -> {},
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
end
