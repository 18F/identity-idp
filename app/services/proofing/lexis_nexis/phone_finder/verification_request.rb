module Proofing
  module LexisNexis
    module PhoneFinder
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
              Phones: [
                {
                  Number: applicant[:phone],
                },
              ],
            },
          }.to_json
        end

        def workflow_name
          config.phone_finder_workflow
        end

        def metric_name
          'lexis_nexis_phone_finder'
        end
      end
    end
  end
end
