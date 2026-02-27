# frozen_string_literal: true

module Idv
  module InPerson
    class PostOfficeController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include StepIndicatorConcern
      include UspsInPersonProofing

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
    end
  end
end
