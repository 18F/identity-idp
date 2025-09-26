# frozen_string_literal: true

module Idv
  class AddressController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include Idv::StepIndicatorConcern

    before_action :confirm_not_rate_limited_after_doc_auth
    before_action :confirm_step_allowed

    def new
      analytics.idv_address_visit

      @address_form = build_address_form
      @presenter = AddressPresenter.new(
        gpo_request_letter_visited: idv_session.gpo_request_letter_visited,
        address_update_request: address_update_request?,
      )
    end

    def update
      clear_future_steps!
      @address_form = build_address_form
      form_result = @address_form.submit(profile_params)
      track_submit_event(form_result)
      if form_result.success?
        success
      else
        failure
      end
    rescue => e
      byebug
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :address,
        controller: self,
        action: :new,
        next_steps: [:verify_info],
        preconditions: ->(idv_session:, user:) { idv_session.remote_document_capture_complete? },
        undo_step: ->(idv_session:, user:) { idv_session.updated_user_address = nil },
      )
    end

    private

    def build_address_form
      Idv::AddressForm.new(
        idv_session.updated_user_address || address_from_document,
      )
    end

    def address_from_document
      idv_session.pii_from_doc.to_pii_address
    end

    def success
      idv_session.address_edited = address_edited?
      idv_session.updated_user_address = @address_form.updated_user_address
      redirect_to idv_verify_info_url
    end

    def failure
      @presenter = AddressPresenter.new(
        gpo_request_letter_visited: idv_session.gpo_request_letter_visited,
        address_update_request: address_update_request?,
      )
      render :new
    end

    def track_submit_event(form_result)
      analytics.idv_address_submitted(
        **form_result.to_h.merge(
          address_edited: address_edited?,
        ),
      )
      attempts_api_tracker.idv_address_submitted(
        success: form_result.success?,
        address1: @address_form.address1,
        address2: @address_form.address2,
        address_edited: address_edited?,
        city: @address_form.city,
        state: @address_form.state,
        zip: @address_form.zipcode,
        failure_reason: attempts_api_tracker.parse_failure_reason(form_result),
      )
      fraud_ops_tracker.idv_address_submitted(
        success: form_result.success?,
        address1: @address_form.address1,
        address2: @address_form.address2,
        address_edited: address_edited?,
        city: @address_form.city,
        state: @address_form.state,
        zip: @address_form.zipcode,
        failure_reason: fraud_ops_tracker.parse_failure_reason(form_result),
      )
    end

    def address_update_request?
      idv_verify_info_url == request.referer
    end

    def address_edited?
      address_from_document != @address_form.updated_user_address
    end

    def profile_params
      params.require(:idv_form).permit(Idv::AddressForm::ATTRIBUTES)
    end

    def step_indicator_steps
      if idv_session.gpo_request_letter_visited
        return StepIndicatorConcern::STEP_INDICATOR_STEPS_GPO
      end

      StepIndicatorConcern::STEP_INDICATOR_STEPS
    end
  end
end
