# frozen_string_literal: true

module Idv
  module InPerson
    class StateIdController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include Idv::IdConcern

      before_action :set_usps_form_presenter
      before_action :confirm_step_allowed
      before_action :initialize_pii_from_user, only: [:show]

      def show
        analytics.idv_in_person_proofing_state_id_visited(**analytics_arguments)

        render :show, locals: extra_view_variables
      end

      def update
        # don't clear the ssn when updating address, clear after SsnController
        clear_future_steps_from!(controller: Idv::InPerson::SsnController)

        initial_state_of_same_address_as_id = pii_from_user[:same_address_as_id]

        form_result = form.submit(flow_params)

        if form_result.success?
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            pii_from_user[attr] = flow_params[attr]
          end

          # Accept Date of Birth from both memorable date and input date components
          formatted_dob = MemorableDateComponent.extract_date_param flow_params&.[](:dob)
          pii_from_user[:dob] = formatted_dob if formatted_dob

          # Accept Expiration Date from both memorable date and input date components
          formatted_exp = MemorableDateComponent.extract_date_param(
            flow_params&.[](:id_expiration),
          )
          if formatted_exp
            pii_from_user[:state_id_expiration] = formatted_exp
            pii_from_user.delete(:id_expiration)
          end

          if pii_from_user[:same_address_as_id] == 'true'
            copy_state_id_address_to_residential_address(pii_from_user)
            redirect_url = idv_in_person_ssn_url
          end

          if initial_state_of_same_address_as_id == 'true' &&
             pii_from_user[:same_address_as_id] == 'false'
            clear_residential_address(pii_from_user)
          end

          if (idv_session.ssn && pii_from_user[:same_address_as_id] == 'true') ||
             initial_state_of_same_address_as_id == 'false'
            redirect_url = idv_in_person_verify_info_url
          elsif pii_from_user[:same_address_as_id] == 'false'
            redirect_url = idv_in_person_address_url
          else
            redirect_url = idv_in_person_ssn_url
          end

          enrollment.update!(document_type: :state_id)
          idv_session.doc_auth_vendor = Idp::Constants::Vendors::USPS

          analytics.idv_in_person_proofing_state_id_submitted(
            **analytics_arguments.merge(**form_result),
          )

          redirect_to redirect_url
        else
          render :show, locals: extra_view_variables
        end
      end

      def extra_view_variables
        {
          form:,
          pii:,
          parsed_dob:,
          parsed_expiration:,
          updating_state_id: updating_state_id?,
        }
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :ipp_state_id,
          controller: self,
          next_steps: [:ipp_address, :ipp_ssn],
          preconditions: ->(idv_session:, user:) do
            user.has_establishing_in_person_enrollment? &&
              !idv_session.opted_in_to_in_person_proofing.nil?
          end,
          undo_step: ->(idv_session:, user:) do
            idv_session.invalidate_in_person_pii_from_user!
          end,
        )
      end

      private

      def analytics_arguments
        {
          flow_path: idv_session.flow_path,
          step: 'state_id',
          analytics_id: 'In Person Proofing',
        }.merge(ab_test_analytics_buckets)
          .merge(extra_analytics_properties)
      end

      def clear_residential_address(pii_from_user)
        pii_from_user.delete(:address1)
        pii_from_user.delete(:address2)
        pii_from_user.delete(:city)
        pii_from_user.delete(:state)
        pii_from_user.delete(:zipcode)
      end

      def copy_state_id_address_to_residential_address(pii_from_user)
        pii_from_user[:address1] = flow_params[:identity_doc_address1]
        pii_from_user[:address2] = flow_params[:identity_doc_address2]
        pii_from_user[:city] = flow_params[:identity_doc_city]
        pii_from_user[:state] = flow_params[:identity_doc_address_state]
        pii_from_user[:zipcode] = flow_params[:identity_doc_zipcode]
      end

      def updating_state_id?
        user_session.dig(:idv, :ssn).present?
      end

      def parsed_dob
        parse_date(pii[:dob])
      end

      def parsed_expiration
        parse_date(pii[:id_expiration])
      end

      def pii
        data = pii_from_user
        if params.has_key?(:identity_doc) || params.has_key?(:state_id)
          data = data.merge(flow_params)
        end
        data[:id_expiration] = data.delete(:state_id_expiration) if data.key?(:state_id_expiration)
        data.deep_symbolize_keys
      end

      def flow_params
        if params.dig(:identity_doc).present?
          # Transform the top-level params key to accept the renamed form
          # for autofill handling workaround
          params[:state_id] = params.delete(:identity_doc)

          # Rename nested id_number to state_id_number
          if params[:state_id][:id_number].present?
            params[:state_id][:state_id_number] = params[:state_id].delete(:id_number)
          end
        end

        params.require(:state_id).permit(
          *Idv::StateIdForm::ATTRIBUTES,
          dob: [
            :month,
            :day,
            :year,
          ],
          id_expiration: [
            :month,
            :day,
            :year,
          ],
        )
      end

      def enrollment
        current_user.establishing_in_person_enrollment
      end

      def form
        @form ||= Idv::StateIdForm.new(current_user)
      end

      def set_usps_form_presenter
        @presenter = Idv::InPerson::UspsFormPresenter.new
      end

      def initialize_pii_from_user
        user_session['idv/in_person'] ||= {}
        user_session['idv/in_person']['pii_from_user'] ||= { uuid: current_user.uuid }
      end
    end
  end
end
