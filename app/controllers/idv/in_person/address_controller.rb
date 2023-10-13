module Idv
  module InPerson
    class AddressController < ApplicationController
      include IdvStepConcern

      def show
        analytics.idv_in_person_proofing_address_visited

        render :show, locals: extra_view_variables
      end

      def update
        attrs = Idv::InPerson::AddressForm::ATTRIBUTES

        attrs = attrs.difference([:same_address_as_id])
        flow_session[:pii_from_user][:same_address_as_id] = 'false' if updating_address?

        attrs.each do |attr|
          flow_session[:pii_from_user][attr] = flow_params[attr]
        end

        puts "form: #{form_submit.pretty_inspect}"
        puts "pii: #{pii}"
        form_result = form_submit
        analytics.idv_in_person_proofing_residential_address_submitted(**form_result.to_h)

        if updating_address?
          redirect_to idv_in_person_verify_info_url
        else
          redirect_to idv_in_person_ssn_url
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

      def form_submit
        form.submit(flow_params)
      end
    end
  end
end
