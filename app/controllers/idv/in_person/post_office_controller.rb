# frozen_string_literal: true

module Idv
  module InPerson
    class PostOfficeController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include StepIndicatorConcern
      include UspsInPersonProofing
      include Idv::HybridMobile::HybridMobileConcern

      def show
        @presenter = Idv::InPerson::PostOfficePresenter.new
      end

      def search
        @presenter = Idv::InPerson::PostOfficePresenter.new

        candidate = UspsInPersonProofing::Applicant.new(
          address: search_params['street_address'],
          city: search_params['city'],
          state: search_params['state'],
          zip_code: search_params['zip_code'],
        )
        @search_values = search_params

        @post_offices = proofer.request_facilities(candidate, false)
      end

      def update
        # TODO: create needed enrollment and session data

        enrollment.update!(
          selected_location_details: selected_location,
          issuer: current_sp&.issuer,
          doc_auth_result: document_capture_session&.last_doc_auth_result,
          sponsor_id: enrollment_sponsor_id,
          document_type: nil,
        )

        redirect_to idv_in_person_url
      end

      private

      def search_params
        params.require(:address).permit(
          :street_address,
          :city,
          :state,
          :zip_code,
        )
      end

      def post_office_params
        params.require(:post_office).permit(
          :name,
          :street_address,
          :weekday_hours,
          :saturday_hours,
          :sunday_hours,
          :city,
          :state,
          :zip_code_5,
          :zip_code_4,
        )
      end

      def selected_location
        params.require(:post_office).permit(
          :formatted_city_state_zip,
          :name,
          :saturday_hours,
          :street_address,
          :sunday_hours,
          :weekday_hours,
        )
      end

      def formatted_city_state_zip
        "#{post_office_params[:city]}, #{post_office_params[:state]}, #{post_office_params[:zip_code_5]}-#{post_office_params[:zip_code_4]}"
      end

      def proofer
        @proofer ||= EnrollmentHelper.usps_proofer
      end

      def enrollment
        InPersonEnrollment.find_or_initialize_by(
          user: current_or_hybrid_user,
          status: :establishing,
          profile: nil,
        )
      end

      def enrollment_sponsor_id
        authn_context_enhanced_ipp? ?
          IdentityConfig.store.usps_eipp_sponsor_id :
          IdentityConfig.store.usps_ipp_sponsor_id
      end

      def authn_context_enhanced_ipp?
        resolved_authn_context_result.enhanced_ipp?
      end
    end
  end
end
