module Idv
  module InPerson
    class AddressController < ApplicationController
      include IdvStepConcern

      before_action :render_404_if_in_person_residential_address_controller_enabled_not_set
      before_action :confirm_in_person_state_id_step_complete
      before_action :confirm_in_person_address_step_needed

      def show
        analytics.idv_in_person_proofing_address_visited(**analytics_arguments)

        render :show, locals: extra_view_variables
      end

      def extra_view_variables
        {
          form:,
          pii:,
          updating_address: updating_address?,
        }
      end

      private

      def flow_session
        user_session.fetch('idv/in_person', {})
      end

      def updating_address?
        flow_session[:pii_from_user].has_key?(:address1) && user_session[:idv].has_key?(:ssn)
      end

      def pii
        data = flow_session[:pii_from_user]
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

      def form_submit
        form.submit(flow_params)
      end

      def analytics_arguments
        {
          flow_path:,
          step: 'address',
          analytics_id: 'In Person Proofing',
          irs_reproofing: irs_reproofing?,
        }
      end

      def render_404_if_in_person_residential_address_controller_enabled_not_set
        render_not_found unless
            IdentityConfig.store.in_person_residential_address_controller_enabled
      end

      def confirm_in_person_state_id_step_complete
        return if pii_from_user&.has_key?(:identity_doc_address1)
        redirect_to idv_in_person_step_url(step: :state_id)
      end

      def confirm_in_person_address_step_needed
        return if pii_from_user && pii_from_user[:same_address_as_id] == 'false' &&
                  !pii_from_user.has_key?(:address1)
        redirect_to idv_in_person_ssn_url
      end
    end
  end
end
