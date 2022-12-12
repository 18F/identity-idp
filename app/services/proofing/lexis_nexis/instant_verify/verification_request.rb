module Proofing
  module LexisNexis
    module InstantVerify
      class VerificationRequest < Request
        private

        def build_request_body
          {
            Settings: {
              AccountNumber: account_number,
              Mode: mode,
              Reference: uuid,
              Locale: 'en_US',
              Venue: 'online',
            },
            Person: {
              Name: {
                FirstName: applicant[:first_name],
                LastName: applicant[:last_name],
              },
              SSN: {
                Number: applicant[:ssn].gsub(/\D/, ''),
                Type: 'ssn9',
              },
              DateOfBirth: DateFormatter.new(applicant[:dob]).formatted_date,
              Addresses: [formatted_address],
              Licenses: [
                {
                  Number: applicant[:state_id_number],
                  Issuer: applicant[:state_id_jurisdiction],
                  Type: 'drivers',
                },
              ],
            },
          }.to_json
        end

        def workflow_name
          config.instant_verify_workflow
        end

        def formatted_address
          {
            StreetAddress1: applicant[:address1],
            StreetAddress2: applicant[:address2] || '',
            City: applicant[:city],
            State: applicant[:state],
            Zip5: applicant[:zipcode].match(/^\d{5}/).to_s,
            Country: 'US',
            Context: 'primary',
          }
        end

        def metric_name
          'lexis_nexis_instant_verify'
        end

        def timeout
          IdentityConfig.store.lexisnexis_instant_verify_timeout
        end
      end
    end
  end
end
