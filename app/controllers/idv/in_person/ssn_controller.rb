module Idv
  module InPerson
    class SsnController < ApplicationController
      include IdvStepConcern
      include StepIndicatorConcern
      include Steps::ThreatMetrixStepHelper
      include ThreatMetrixConcern

      before_action :confirm_verify_info_step_needed
      before_action :confirm_in_person_address_step_complete
      before_action :confirm_repeat_ssn, only: :show
      before_action :override_csp_for_threat_metrix_no_fsm

      attr_accessor :error_message

      def show
        @ssn_form = Idv::SsnFormatForm.new(current_user, idv_session.ssn)

        analytics.idv_doc_auth_redo_ssn_submitted(**analytics_arguments) if updating_ssn?
        analytics.idv_doc_auth_ssn_visited(**analytics_arguments)

        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('ssn', :view, true)

        render :show, locals: extra_view_variables
      end

      def update
        @error_message = nil
        @ssn_form = Idv::SsnFormatForm.new(current_user, idv_session.ssn)
        ssn = params.require(:doc_auth).permit(:ssn)
        form_response = @ssn_form.submit(ssn)

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
          redirect_to idv_in_person_verify_info_url
        else
          @error_message = form_response.first_error_message
          render :show, locals: extra_view_variables
        end
      end

      def extra_view_variables
        {
          updating_ssn: updating_ssn?,
          **threatmetrix_view_variables,
        }
      end

      private

      def flow_session
        user_session.fetch('idv/in_person', {})
      end

      def flow_path
        flow_session[:flow_path]
      end

      def confirm_repeat_ssn
        return if !idv_session.ssn
        return if request.referer == idv_in_person_verify_info_url
        redirect_to idv_in_person_verify_info_url
      end

      def analytics_arguments
        {
          flow_path: flow_path,
          step: 'ssn',
          analytics_id: 'In Person Proofing',
          irs_reproofing: irs_reproofing?,
        }.merge(ab_test_analytics_buckets).
          merge(**extra_analytics_properties)
      end

      def updating_ssn?
        idv_session.ssn.present?
      end

      def confirm_in_person_address_step_complete
        return if pii_from_user && pii_from_user[:address1].present?
        redirect_to idv_in_person_step_url(step: :address)
      end
    end
  end
end
