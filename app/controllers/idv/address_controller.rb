# frozen_string_literal: true

module Idv
  class AddressController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern

    before_action :confirm_not_rate_limited_after_doc_auth
    before_action :confirm_step_allowed

    def new
      analytics.idv_address_visit

      @address_form = build_address_form
      @presenter = AddressPresenter.new(
        gpo_letter_requested: idv_session.gpo_letter_requested,
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
        idv_session.updated_user_address || address_from_document || null_address,
      )
    end

    def address_from_document
      return if idv_session.pii_from_doc.id_doc_type == 'passport'

      Pii::Address.new(
        address1: idv_session.pii_from_doc.address1,
        address2: idv_session.pii_from_doc.address2,
        city: idv_session.pii_from_doc.city,
        state: idv_session.pii_from_doc.state,
        zipcode: idv_session.pii_from_doc.zipcode,
      )
    end

    def null_address
      Pii::Address.new(
        address1: nil,
        address2: nil,
        city: nil,
        state: nil,
        zipcode: nil,
      )
    end

    def success
      idv_session.address_edited = address_edited?
      idv_session.updated_user_address = @address_form.updated_user_address
      redirect_to idv_verify_info_url
    end

    def failure
      @presenter = AddressPresenter.new(
        gpo_letter_requested: idv_session.gpo_letter_requested,
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
  end
end
