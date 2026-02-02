# frozen_string_literal: true

module Idv
  module InPerson
    class StateIdController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include Idv::IdConcern
      include Idv::InPersonAamvaConcern

      before_action :set_usps_form_presenter
      before_action :confirm_step_allowed
      before_action :initialize_pii_from_user, only: [:show]

      def show
        if idv_session.ipp_aamva_document_capture_session_uuid.present?
          process_aamva_async_state
          return
        end

        analytics.idv_in_person_proofing_state_id_visited(**analytics_arguments)

        render :show, locals: extra_view_variables
      end

      def update
        clear_future_steps_from!(controller: Idv::InPerson::SsnController)

        initial_state_of_same_address_as_id = pii_from_user[:same_address_as_id]

        form_result = form.submit(flow_params)

        if form_result.success?
          pending_pii = build_pending_pii
          redirect_url = determine_redirect_url(pending_pii, initial_state_of_same_address_as_id)
          idv_session.doc_auth_vendor = Idp::Constants::Vendors::USPS

          analytics.idv_in_person_proofing_state_id_submitted(
            **analytics_arguments.merge(**form_result),
          )

          if aamva_enabled?
            idv_session.ipp_aamva_pending_state_id_pii = pending_pii
            idv_session.ipp_aamva_redirect_url = redirect_url

            if rate_limit_redirect!(:idv_doc_auth, step_name: 'ipp_state_id')
              clear_aamva_async_session
              clear_aamva_pending_pii
              return
            end

            start_aamva_async_state
            redirect_to idv_in_person_state_id_url
            return
          end

          commit_state_id_data(pending_pii)
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
            idv_session.source_check_vendor = nil
            idv_session.ipp_aamva_result = nil
            idv_session.ipp_aamva_pending_state_id_pii = nil
          end,
        )
      end

      private

      def build_pending_pii
        pending = pii_from_user.dup

        Idv::StateIdForm::ATTRIBUTES.each do |attr|
          pending[attr] = flow_params[attr]
        end

        formatted_dob = MemorableDateComponent.extract_date_param flow_params&.[](:dob)
        pending[:dob] = formatted_dob if formatted_dob

        formatted_exp = MemorableDateComponent.extract_date_param(
          flow_params&.[](:id_expiration),
        )
        if formatted_exp
          pending[:state_id_expiration] = formatted_exp
          pending.delete(:id_expiration)
        end

        if pending[:same_address_as_id] == 'true'
          pending[:address1] = flow_params[:identity_doc_address1]
          pending[:address2] = flow_params[:identity_doc_address2]
          pending[:city] = flow_params[:identity_doc_city]
          pending[:state] = flow_params[:identity_doc_address_state]
          pending[:zipcode] = flow_params[:identity_doc_zipcode]
        end

        pending
      end

      def determine_redirect_url(pending_pii, initial_state_of_same_address_as_id)
        if initial_state_of_same_address_as_id == 'true' &&
           pending_pii[:same_address_as_id] == 'false'
          # Address changed from same to different, clear residential address
          pending_pii.delete(:address1)
          pending_pii.delete(:address2)
          pending_pii.delete(:city)
          pending_pii.delete(:state)
          pending_pii.delete(:zipcode)
        end

        if (idv_session.ssn && pending_pii[:same_address_as_id] == 'true') ||
           initial_state_of_same_address_as_id == 'false'
          idv_in_person_verify_info_url
        elsif pending_pii[:same_address_as_id] == 'false'
          idv_in_person_address_url
        else
          idv_in_person_ssn_url
        end
      end

      def analytics_arguments
        {
          flow_path: idv_session.flow_path,
          step: 'state_id',
          analytics_id: 'In Person Proofing',
        }.merge(ab_test_analytics_buckets)
          .merge(extra_analytics_properties)
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
        data = idv_session.ipp_aamva_pending_state_id_pii || pii_from_user
        if params.has_key?(:identity_doc) || params.has_key?(:state_id)
          data = data.merge(flow_params)
        end
        data[:id_expiration] = data.delete(:state_id_expiration) if data.key?(:state_id_expiration)
        data.deep_symbolize_keys
      end

      def flow_params
        if params.dig(:identity_doc).present?
          params[:state_id] = params.delete(:identity_doc)

          if params[:state_id][:id_number].present?
            params[:state_id][:state_id_number] = params[:state_id].delete(:id_number)
          end
        end

        params.require(:state_id).permit(
          *Idv::StateIdForm::ATTRIBUTES,
          dob: [:month, :day, :year],
          id_expiration: [:month, :day, :year],
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
