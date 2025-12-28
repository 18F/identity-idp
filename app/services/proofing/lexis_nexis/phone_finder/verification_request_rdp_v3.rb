# frozen_string_literal: true

module Proofing
  module LexisNexis
    module PhoneFinder
      class VerificationRequestRdpV3 < AuthenticatedRequest
        private

        def build_request_body
          {
            Type: 'Initiate', # per email from Eric Montanez, 12/11/2025
            Settings: {
              AccountNumber: account_number,
              Mode: mode,
              Reference: uuid,
              Locale: 'en_US',
              Venue: 'online',
            },
            Persons: [{
              Context: :primary,
              Name: {
                FirstName: applicant[:first_name],
                LastName: applicant[:last_name],
              },
              SSN: {
                Number: applicant[:ssn].gsub(/\D/, ''),
                Type: 'ssn9',
              },
              DateOfBirth: DateFormatter.new(applicant[:dob], rdp_version: :rdp_v3).formatted_date,
              Phones: [
                {
                  Number: applicant[:phone],
                },
              ],
            }],
          }.to_json
        end

        def url_request_path
          "/restws/identity/v3/accounts/#{account_number}/workflows/#{workflow_name}/conversations"
        end

        def workflow_name
          config.phone_finder_workflow
        end

        def metric_name
          'lexis_nexis_phone_finder'
        end

        def timeout
          IdentityConfig.store.lexisnexis_phone_finder_timeout
        end
      end
    end
  end
end
