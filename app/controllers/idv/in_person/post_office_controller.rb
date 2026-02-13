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

      private

      def search_params
        params.require(:address).permit(
          :street_address,
          :city,
          :state,
          :zip_code,
        )
      end

      def proofer
        @proofer ||= EnrollmentHelper.usps_proofer
      end
    end
  end
end
