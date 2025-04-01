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
      @presenter = AddressPresenter.new
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
      return if idv_session.pii_from_doc.state_id_type == 'passport'

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
      @presenter = AddressPresenter.new
      render :new
    end

    def track_submit_event(form_result)
      analytics.idv_address_submitted(
        **form_result.to_h.merge(
          address_edited: address_edited?,
        ),
      )
    end

    def address_edited?
      address_from_document != @address_form.updated_user_address
    end

    def profile_params
      params.require(:idv_form).permit(Idv::AddressForm::ATTRIBUTES)
    end
  end
end
