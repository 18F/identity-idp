# frozen_string_literal: true

module Idv
  class AddressController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern

    before_action :confirm_not_rate_limited_after_doc_auth
    before_action :confirm_step_allowed

    def new
      analytics.idv_address_visit

      @address_form = Idv::AddressForm.new(idv_session.pii_from_doc)
      @presenter = AddressPresenter.new
    end

    def update
      clear_future_steps!
      @address_form = Idv::AddressForm.new(idv_session.pii_from_doc)
      form_result = @address_form.submit(profile_params)
      analytics.idv_address_submitted(**form_result.to_h)
      capture_address_edited(form_result)
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

    def idv_form
      Idv::AddressForm.new(idv_session.pii_from_doc)
    end

    def success
      idv_session.pii_from_doc = idv_session.pii_from_doc.merge(
        address1: @address_form.address1,
        address2: @address_form.address2,
        city: @address_form.city,
        state: @address_form.state,
        zipcode: @address_form.zipcode,
      )
      idv_session.updated_user_address = address_from_form
      redirect_to idv_verify_info_url
    end

    def failure
      @presenter = AddressPresenter.new
      render :new
    end

    def address_from_form
      Pii::Address.new(
        address1: @address_form.address1,
        address2: @address_form.address2,
        city: @address_form.city,
        state: @address_form.state,
        zipcode: @address_form.zipcode,
      )
    end

    def profile_params
      params.require(:idv_form).permit(Idv::AddressForm::ATTRIBUTES)
    end

    def capture_address_edited(result)
      address_edited = result.to_h[:address_edited]
      idv_session.address_edited = true if address_edited
    end
  end
end
