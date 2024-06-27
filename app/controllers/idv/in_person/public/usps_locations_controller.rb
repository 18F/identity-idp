# frozen_string_literal: true

module Idv
  module InPerson
    module Public
      class UspsLocationsController < ApplicationController
        include RenderConditionConcern

        check_or_render_not_found -> { enabled? }

        skip_forgery_protection

        def index
          candidate = UspsInPersonProofing::Applicant.new(
            address: search_params['street_address'],
            city: search_params['city'], state: search_params['state'],
            zip_code: search_params['zip_code']
          )
          locations = proofer.request_facilities(candidate, false)

          render json: localized_locations(locations).to_json
        end

        def options
          head :ok
        end

        private

        def proofer
          @proofer ||= UspsInPersonProofing::EnrollmentHelper.usps_proofer
        end

        def localized_locations(locations)
          return nil if locations.nil?
          locations.map do |location|
            {
              address: location[:address],
              city: location[:city],
              distance: location[:distance],
              name: location[:name],
              saturday_hours: UspsInPersonProofing::EnrollmentHelper.localized_hours(
                location[:saturday_hours],
              ),
              state: location[:state],
              sunday_hours: UspsInPersonProofing::EnrollmentHelper.localized_hours(
                location[:sunday_hours],
              ),
              weekday_hours: UspsInPersonProofing::EnrollmentHelper.localized_hours(
                location[:weekday_hours],
              ),
              zip_code_4: location[:zip_code_4],
              zip_code_5: location[:zip_code_5],
              is_pilot: location[:is_pilot],
            }
          end
        end

        def enabled?
          IdentityConfig.store.in_person_public_address_search_enabled
        end

        def search_params
          params.require(:address).permit(
            :street_address,
            :city,
            :state,
            :zip_code,
          )
        end
      end
    end
  end
end
