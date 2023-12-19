module Idv
  module InPerson
    class AddressController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern

      before_action :render_404_if_in_person_residential_address_controller_enabled_not_set
      before_action :confirm_in_person_state_id_step_complete
      before_action :confirm_in_person_address_step_needed, only: :show

      def show
        analytics.idv_in_person_proofing_address_visited(**analytics_arguments)

        render :show, locals: extra_view_variables
      end

      def update
        attrs = Idv::InPerson::AddressForm::ATTRIBUTES.difference([:same_address_as_id])
        pii_from_user[:same_address_as_id] = 'false' if updating_address?
        form_result = form.submit(flow_params)

        analytics.idv_in_person_proofing_residential_address_submitted(
          **analytics_arguments.merge(**form_result.to_h),
        )

        if form_result.success?
          attrs.each do |attr|
            pii_from_user[attr] = flow_params[attr]
          end
          flow_session['Idv::Steps::InPerson::AddressStep'] = true
          redirect_to_next_page
        else
          render :show, locals: extra_view_variables
        end
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

      def analytics_arguments
        {
          flow_path: idv_session.flow_path,
          step: 'address',
          analytics_id: 'In Person Proofing',
          irs_reproofing: irs_reproofing?,
        }.merge(ab_test_analytics_buckets).
          merge(extra_analytics_properties)
      end

      def redirect_to_next_page
        if updating_address?
          redirect_to idv_in_person_verify_info_url
        else
          redirect_to idv_in_person_ssn_url
        end
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
        return if request.referer == idv_in_person_verify_info_url
        redirect_to idv_in_person_ssn_url
      end
    end
  end
end
