# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      module Requests
        class PhoneRiskRequest < Proofing::Socure::IdPlus::Request
          def body
            @body ||= {
              modules: ['phonerisk'],
              mobileNumber: input.phone,
              country: 'US',

              # optional fields
              customerUserId: config.user_uuid,
              firstName: input.first_name,
              surName: input.last_name,
              physicalAddress: input.address1,
              physicalAddress2: input.address2,
              city: input.city,
              state: input.state,
              zip: input.zipcode,
              email: input.email,
            }.to_json
          end

          private

          def fetch_response
            Proofing::Socure::IdPlus::Responses::PhoneRiskResponse.new(
              conn.post(url, body, headers) do |req|
                req.options.context = { service_name: SERVICE_NAME }
              end,
            )
          end
        end
      end
    end
  end
end
