module Idv
  class AddressController < ApplicationController
    include IdvStepConcern

    before_action :confirm_not_rate_limited_after_doc_auth
    before_action :confirm_step_allowed

    def new
      analytics.idv_address_visit

      @presenter = AddressPresenter.new(pii: idv_session.pii_from_doc)
    end

    def update
      clear_future_steps!
      form_result = idv_form.submit(profile_params)
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
        undo_step: ->(idv_session:, user:) {},
      )
    end

    private

    def idv_form
      Idv::AddressForm.new(idv_session.pii_from_doc_or_applicant)
    end

    def success
      profile_params.each do |key, value|
        idv_session.pii_from_doc[key] = value
      end
      redirect_to idv_verify_info_url
    end

    def failure
      redirect_to idv_address_url
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
