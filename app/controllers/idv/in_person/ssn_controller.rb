module Idv
  module InPerson
    class SsnController < ApplicationController
      include IdvStepConcern
      include StepIndicatorConcern
      include StepUtilitiesConcern
      include Steps::ThreatMetrixStepHelper
      include ThreatMetrixConcern

      before_action :renders_404_if_in_person_ssn_info_controller_enabled_flag_not_set
      before_action :confirm_verify_info_step_needed
      before_action :confirm_in_person_address_step_complete
      before_action :confirm_repeat_ssn, only: :show
      ## TO DO: ARE WE DOING THREATMETRIX? IF YES, KEEP
      before_action :override_csp_for_threat_metrix_no_fsm

      attr_accessor :error_message

      def show
        @ssn_form = Idv::SsnFormatForm.new(current_user, flow_session)

        analytics.idv_doc_auth_redo_ssn_submitted(**analytics_arguments) if updating_ssn?
        analytics.idv_doc_auth_ssn_visited(**analytics_arguments)

        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('ssn', :view, true)

        render :show, locals: extra_view_variables
      end

      def update
        @error_message = nil

        @ssn_form = Idv::SsnFormatForm.new(current_user, flow_session)
        ssn = params.require(:doc_auth).permit(:ssn)
        form_response = @ssn_form.submit(ssn)

        analytics.idv_doc_auth_ssn_submitted(
          **analytics_arguments.merge(form_response.to_h),
        )
        irs_attempts_api_tracker.idv_ssn_submitted(
          ssn: params[:doc_auth][:ssn],
        )

        if form_response.success?
          flow_session['pii_from_user'][:ssn] = params[:doc_auth][:ssn]

          idv_session.invalidate_steps_after_ssn!
          redirect_to next_url
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

      ##
      # In order to test the behavior without the threatmetrix JS, we do not load the threatmetrix
      # JS if the user's email is on a list of JS disabled emails.
      #
      def should_render_threatmetrix_js?
        return false unless FeatureManagement.proofing_device_profiling_collecting_enabled?

        current_user.email_addresses.each do |email_address|
          no_csp_email = IdentityConfig.store.idv_tmx_test_js_disabled_emails.include?(
            email_address.email,
          )
          return false if no_csp_email
        end

        true
      end

      private

      def flow_session
        user_session.fetch('idv/in_person', {})
      end

      def flow_path
        flow_session[:flow_path]
      end

      def confirm_repeat_ssn
        return if !pii_from_user[:ssn]
        return if request.referer == idv_in_person_verify_info_url
        redirect_to idv_in_person_verify_info_url
      end

      def next_url
        idv_in_person_verify_info_url
      end

      def analytics_arguments
        {
          flow_path: flow_path,
          step: 'ssn',
          analytics_id: 'In Person Proofing',
          irs_reproofing: irs_reproofing?,
        }.merge(**acuant_sdk_ab_test_analytics_args)
      end

      def updating_ssn?
        flow_session.dig(:pii_from_user, :ssn).present?
      end

      def renders_404_if_in_person_ssn_info_controller_enabled_flag_not_set
        render_not_found unless IdentityConfig.store.in_person_ssn_info_controller_enabled
      end

      def confirm_in_person_address_step_complete
        return if pii_from_user && pii_from_user[:address1].present?
        redirect_to idv_in_person_step_url(step: :address)
      end
    end
  end
end
