# frozen_string_literal: true

module Idv
  module InPerson
    class SsnController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include StepIndicatorConcern
      include Steps::ThreatMetrixStepHelper
      include ThreatMetrixConcern

      before_action :confirm_step_allowed
      before_action :confirm_not_rate_limited_after_doc_auth
      before_action :override_csp_for_threat_metrix,
                    if: -> { FeatureManagement.proofing_device_profiling_collecting_enabled? }

      attr_reader :ssn_presenter

      # Keep this code in sync with Idv::SsnController

      def show
        @ssn_presenter = Idv::SsnPresenter.new(
          sp_name: decorated_sp_session.sp_name,
          ssn_form: Idv::SsnFormatForm.new(idv_session.ssn),
          step_indicator_steps: step_indicator_steps,
        )

        if ssn_presenter.updating_ssn?
          analytics.idv_doc_auth_redo_ssn_submitted(**analytics_arguments)
        end
        analytics.idv_doc_auth_ssn_visited(**analytics_arguments)

        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer])
          .call('ssn', :view, true)

        render 'idv/shared/ssn', locals: threatmetrix_view_variables(ssn_presenter.updating_ssn?)
      end

      def update
        clear_future_steps!
        ssn_form = Idv::SsnFormatForm.new(idv_session.ssn)
        ssn_params = params.require(:doc_auth).permit(:ssn)
        form_response = ssn_form.submit(ssn_params)
        @ssn_presenter = Idv::SsnPresenter.new(
          sp_name: decorated_sp_session.sp_name,
          ssn_form: ssn_form,
          step_indicator_steps: step_indicator_steps,
        )

        attempts_api_tracker.idv_ssn_submitted(
          success: form_response.success?,
          social_security: ssn_params[:ssn],
          failure_reason: attempts_api_tracker.parse_failure_reason(form_response),
        )

        if form_response.success?
          idv_session.previous_ssn = idv_session.ssn
          idv_session.ssn = SsnFormatter.normalize(params[:doc_auth][:ssn])
          redirect_to next_url
        else
          flash[:error] = form_response.first_error_message
          render 'idv/shared/ssn', locals: threatmetrix_view_variables(ssn_presenter.updating_ssn?)
        end

        analytics.idv_doc_auth_ssn_submitted(
          **analytics_arguments.merge(form_response.to_h),
        )
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :ipp_ssn,
          controller: self,
          next_steps: [:ipp_verify_info],
          preconditions: ->(idv_session:, user:) {
            idv_session.ipp_document_capture_complete?
          },
          undo_step: ->(idv_session:, user:) {
            idv_session.invalidate_ssn_step!
          },
        )
      end

      private

      def next_url
        idv_in_person_verify_info_url
      end

      def analytics_arguments
        {
          flow_path: idv_session.flow_path,
          step: 'ssn',
          analytics_id: 'In Person Proofing',
          previous_ssn_edit_distance: previous_ssn_edit_distance,
        }.merge(ab_test_analytics_buckets)
          .merge(**extra_analytics_properties)
      end
    end
  end
end
