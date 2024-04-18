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
            flow_session[:pii_from_user][:identity_doc_address1] = nil
            flow_session[:pii_from_user][:identity_doc_address2] = nil
            flow_session[:pii_from_user][:identity_doc_city] = nil
            flow_session[:pii_from_user][:identity_doc_zipcode] = nil
            flow_session[:pii_from_user][:identity_doc_state] = nil
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
          irs_reproofing: irs_reproofing?,
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
        flow_session[:pii_from_user].has_key?(:first_name)
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
        data = flow_session[:pii_from_user]
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
