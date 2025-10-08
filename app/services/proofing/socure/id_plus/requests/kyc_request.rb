# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      module Requests
        class KycRequest < Proofing::Socure::IdPlus::Request
          def body
            @body ||= {
              modules: ['kyc'],
              customerUserId: config.user_uuid,

              firstName: input.first_name,
              surName: input.last_name,
              country: 'US',

              physicalAddress: input.address1,
              physicalAddress2: input.address2,
              city: input.city,
              state: input.state,
              zip: input.zipcode,

              nationalId: input.ssn,
              dob: input.dob&.to_date&.to_s,

              userConsent: true,
              consentTimestamp: input.consent_given_at&.to_time&.iso8601,

              email: config.user_email,
              mobileNumber: input.phone,

              # > The country or jurisdiction from where the transaction originates,
              # > specified in ISO-2 country codes format
              countryOfOrigin: 'US',
            }.to_json
          end

          private

          def fetch_response
            Proofing::Socure::IdPlus::Responses::KycResponse.new(
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
