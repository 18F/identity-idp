module Idv
  module InPerson
    class AddressController < ApplicationController
      include IdvStepConcern

      before_action :render_404_if_not_in_person_residential_address_controller_enabled

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
          flow_path: flow_path,
          step: 'address',
          analytics_id: 'In Person Proofing',
          irs_reproofing: irs_reproofing?,
        }
      end

      def render_404_if_not_in_person_residential_address_controller_enabled
        render_not_found unless
            IdentityConfig.store.in_person_residential_address_controller_enabled
      end
    end
  end
end
