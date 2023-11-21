module Idv
  module InPerson
    class SsnController < ApplicationController
      include IdvStepConcern
      include StepIndicatorConcern
      include Steps::ThreatMetrixStepHelper
      include ThreatMetrixConcern

      before_action :confirm_not_rate_limited_after_doc_auth
      before_action :confirm_in_person_address_step_complete
      before_action :confirm_repeat_ssn, only: :show
      before_action :override_csp_for_threat_metrix

      attr_reader :ssn_presenter

      # Keep this code in sync with Idv::SsnController

      def show
        @ssn_presenter = Idv::SsnPresenter.new(
          sp_name: decorated_sp_session.sp_name,
          ssn_form: Idv::SsnFormatForm.new(idv_session.ssn_or_applicant_ssn),
          step_indicator_steps: step_indicator_steps,
        )

        if ssn_presenter.updating_ssn?
          analytics.idv_doc_auth_redo_ssn_submitted(**analytics_arguments)
        end
        analytics.idv_doc_auth_ssn_visited(**analytics_arguments)

        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('ssn', :view, true)

        render 'idv/shared/ssn', locals: threatmetrix_view_variables(ssn_presenter.updating_ssn?)
      end

      def update
        ssn_form = Idv::SsnFormatForm.new(idv_session.ssn)
        form_response = ssn_form.submit(params.require(:doc_auth).permit(:ssn))
        @ssn_presenter = Idv::SsnPresenter.new(
          sp_name: decorated_sp_session.sp_name,
          ssn_form: ssn_form,
          step_indicator_steps: step_indicator_steps,
        )
        analytics.idv_doc_auth_ssn_submitted(
          **analytics_arguments.merge(form_response.to_h),
        )
        # This event is not currently logging but should be kept as decided in LG-10110
        irs_attempts_api_tracker.idv_ssn_submitted(
          ssn: params[:doc_auth][:ssn],
        )

        if form_response.success?
          idv_session.ssn = params[:doc_auth][:ssn]
          idv_session.invalidate_steps_after_ssn!
          redirect_to next_url
        else
          flash[:error] = form_response.first_error_message
          render 'idv/shared/ssn', locals: threatmetrix_view_variables(ssn_presenter.updating_ssn?)
        end
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :ipp_ssn,
          controller: self,
          next_steps: [:ipp_verify_info],
          preconditions: ->(idv_session:, user:) { idv_session.ipp_document_capture_complete? },
          undo_step: ->(idv_session:, user:) do
            idv_session.ssn = nil
            idv_session.threatmetrix_session_id = nil
          end,
        )
      end

      private

      def flow_session
        user_session.fetch('idv/in_person', {})
      end

      def confirm_repeat_ssn
        return if !idv_session.ssn
        return if request.referer == idv_in_person_verify_info_url
        redirect_to idv_in_person_verify_info_url
      end

      def next_url
        idv_in_person_verify_info_url
      end

      def analytics_arguments
        {
          flow_path: idv_session.flow_path,
          step: 'ssn',
          analytics_id: 'In Person Proofing',
          irs_reproofing: irs_reproofing?,
        }.merge(ab_test_analytics_buckets).
          merge(**extra_analytics_properties)
      end

      def confirm_in_person_address_step_complete
        return if pii_from_user && pii_from_user[:address1].present?
        if IdentityConfig.store.in_person_residential_address_controller_enabled
          redirect_to idv_in_person_proofing_address_url
        else
          redirect_to idv_in_person_step_url(step: :address)
        end
      end
    end
  end
end
