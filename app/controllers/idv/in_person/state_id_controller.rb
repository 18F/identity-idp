# frozen_string_literal: true

module Idv
  module InPerson
    class StateIdController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern

      before_action :render_404_if_controller_not_enabled
      before_action :redirect_unless_enrollment # confirm previous step is complete

      def show
        flow_session[:pii_from_user] ||= {}
        analytics.idv_in_person_proofing_state_id_visited(**analytics_arguments)

        render :show, locals: extra_view_variables
      end

      def update
        # don't clear the ssn when updating address, clear after SsnController
        clear_future_steps_from!(controller: Idv::InPerson::SsnController)

        pii_from_user = flow_session[:pii_from_user]
        initial_state_of_same_address_as_id = pii_from_user[:same_address_as_id]

        form_result = form.submit(flow_params)

        if form_result.success?
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            pii_from_user[attr] = flow_params[attr]
          end

          analytics.idv_in_person_proofing_state_id_submitted(
            **analytics_arguments.merge(**form_result.to_h),
          )
          # Accept Date of Birth from both memorable date and input date components
          formatted_dob = MemorableDateComponent.extract_date_param flow_params&.[](:dob)
          pii_from_user[:dob] = formatted_dob if formatted_dob

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
          updating_state_id: updating_state_id?,
        }
      end

      # update Idv::DocumentCaptureController.step_info.next_steps to include
      # :ipp_state_id instead of :ipp_ssn (or :ipp_address) in delete PR
      def self.step_info
        Idv::StepInfo.new(
          key: :ipp_state_id,
          controller: self,
          next_steps: [:ipp_address, :ipp_ssn],
          preconditions: ->(idv_session:, user:) { user.establishing_in_person_enrollment },
          undo_step: ->(idv_session:, user:) do
            pii_from_user[:identity_doc_address1] = nil
            pii_from_user[:identity_doc_address2] = nil
            pii_from_user[:identity_doc_city] = nil
            pii_from_user[:identity_doc_zipcode] = nil
            pii_from_user[:identity_doc_state] = nil
          end,
        )
      end

      private

      def render_404_if_controller_not_enabled
        render_not_found unless
            IdentityConfig.store.in_person_state_id_controller_enabled
      end

      def redirect_unless_enrollment
        redirect_to idv_document_capture_url unless current_user.establishing_in_person_enrollment
      end

      def flow_session
        user_session.fetch('idv/in_person', {})
      end

      def analytics_arguments
        {
          flow_path: idv_session.flow_path,
          step: 'state_id',
          analytics_id: 'In Person Proofing',
        }.merge(ab_test_analytics_buckets).
          merge(extra_analytics_properties)
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
        form_dob = pii[:dob]
        if form_dob.instance_of?(String)
          dob_str = form_dob
        elsif form_dob.instance_of?(Hash)
          dob_str = MemorableDateComponent.extract_date_param(form_dob)
        end
        Date.parse(dob_str) unless dob_str.nil?
      rescue StandardError
        # Catch date parsing errors
      end

      def pii
        data = pii_from_user
        data = data.merge(flow_params) if params.has_key?(:state_id)
        data.deep_symbolize_keys
      end

      def flow_params
        params.require(:state_id).permit(
          *Idv::StateIdForm::ATTRIBUTES,
          dob: [
            :month,
            :day,
            :year,
          ],
        )
      end

      def form
        @form ||= Idv::StateIdForm.new(current_user)
      end
    end
  end
  end
