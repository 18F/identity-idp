# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      module Requests
        class PhoneFinderRequest < Request
          private

          def build_request_body
            {
              api_key: config.api_key,
              org_id: config.org_id,
              account_date_of_birth: applicant[:dob] ?
                Date.parse(applicant[:dob]).strftime('%Y%m%d') : '',
              account_first_name: applicant[:first_name] || '',
              account_last_name: applicant[:last_name] || '',
              account_telephone: applicant[:phone],
              event_type: 'ACCOUNT_CREATION',
              customer_event_type: 'phone_finder',
              policy: config.ddp_policy,
              service_type: 'all',
              national_id_number: applicant[:ssn].to_s.gsub(/\D/, ''),
              national_id_type: applicant[:ssn].present? ? 'US_SSN' : '',
              local_attrib_1: applicant[:uuid_prefix] || '',
              local_attrib_3: applicant[:uuid],
            }.to_json
          end

          def metric_name
            'lexis_nexis_ddp_phone_finder'
          end

          def url_request_path
            '/api/attribute-query'
          end

          def timeout
            IdentityConfig.store.lexisnexis_phone_finder_timeout
          end
        end
      end
    end
  end
end
