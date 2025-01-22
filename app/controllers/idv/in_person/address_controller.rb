# frozen_string_literal: true

module Idv
  module InPerson
    class AddressController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern

      before_action :confirm_step_allowed
      before_action :confirm_in_person_address_step_needed, only: :show
      before_action :set_usps_form_presenter

      def show
        analytics.idv_in_person_proofing_address_visited(**analytics_arguments)

        render :show, locals: extra_view_variables
      end

      def update
        # don't clear the ssn when updating address, clear after SsnController
        clear_future_steps_from!(controller: Idv::InPerson::SsnController)
        attrs = Idv::InPerson::AddressForm::ATTRIBUTES.difference([:same_address_as_id])
        pii_from_user[:same_address_as_id] = 'false' if updating_address?
        form_result = form.submit(flow_params)

        analytics.idv_in_person_proofing_residential_address_submitted(
          **analytics_arguments.merge(**form_result),
        )

        if form_result.success?
          attrs.each do |attr|
            pii_from_user[attr] = flow_params[attr]
          end
          redirect_to_next_page
        else
          render :show, locals: extra_view_variables
        end
      end

      def extra_view_variables
        {
          form:,
          pii:,
          updating_address: updating_address?,
        }
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :ipp_address,
          controller: self,
          next_steps: [:ipp_ssn],
          preconditions: ->(idv_session:, user:) { idv_session.ipp_state_id_complete? },
          undo_step: ->(idv_session:, user:) do
            idv_session.invalidate_in_person_address_step!
          end,
        )
      end

      private

      def pii_from_user
        user_session.dig('idv/in_person', :pii_from_user)
      end

      def updating_address?
        pii_from_user.has_key?(:address1) && user_session[:idv].has_key?(:ssn)
      end

      def pii
        data = pii_from_user
        data = data.merge(flow_params) if params.has_key?(:in_person_address)
        data.deep_symbolize_keys
      end

      def form
        @form ||= Idv::InPerson::AddressForm.new
      end

      def flow_params
        params.require(:in_person_address).permit(
          *Idv::InPerson::AddressForm::ATTRIBUTES,
        )
      end

      def analytics_arguments
        {
          flow_path: idv_session.flow_path,
          step: 'address',
          analytics_id: 'In Person Proofing',
        }.merge(ab_test_analytics_buckets)
          .merge(extra_analytics_properties)
      end

      def redirect_to_next_page
        if updating_address?
          redirect_to idv_in_person_verify_info_url
        else
          redirect_to idv_in_person_ssn_url
        end
      end

      def confirm_in_person_address_step_needed
        return if pii_from_user&.dig(:same_address_as_id) == 'false' &&
                  !pii_from_user.has_key?(:address1)
        return if request.referer == idv_in_person_verify_info_url
        redirect_to idv_in_person_ssn_url
      end

      def set_usps_form_presenter
        @presenter = Idv::InPerson::UspsFormPresenter.new
      end
    end
  end
end
