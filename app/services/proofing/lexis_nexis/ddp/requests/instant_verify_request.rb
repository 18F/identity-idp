# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      module Requests
        class InstantVerifyRequest < Proofing::LexisNexis::Ddp::VerificationRequest
          private

          def build_request_body
            {
              api_key: config.api_key,
              org_id: config.org_id,
              account_address_street1: applicant[:address1] || '',
              account_address_street2: applicant[:address2] || '',
              account_address_city: applicant[:city] || '',
              account_address_state: applicant[:state] || '',
              account_address_country: applicant[:state] ? 'US' : '',
              account_address_zip: applicant[:zipcode] || '',
              account_date_of_birth: applicant[:dob] ?
                Date.parse(applicant[:dob]).strftime('%Y%m%d') : '',
              account_first_name: applicant[:first_name] || '',
              account_last_name: applicant[:last_name] || '',
              account_telephone: '', # applicant[:phone], decision was made not to send phone
              account_drivers_license_number: applicant[:state_id_number]&.gsub(/\W/, '') || '',
              account_drivers_license_type: applicant[:state_id_number] ? 'us_dl' : '',
              account_drivers_license_issuer: applicant[:state_id_jurisdiction].to_s.strip || '',
              event_type: 'ACCOUNT_CREATION', # Should it be this??
              policy: config.ddp_policy,
              service_type: 'all',
              national_id_number: applicant[:ssn]&.gsub(/\D/, '') || '',
              national_id_type: applicant[:ssn] ? 'US_SSN' : '',
              local_attrib_1: applicant[:uuid_prefix] || '',
              local_attrib_3: applicant[:uuid],
            }.to_json
          end

          def metric_name
            'lexis_nexis_ddp_instant_verify'
          end

          def url_request_path
            '/api/attribute-query'
          end

          def timeout
            IdentityConfig.store.lexisnexis_instant_verify_timeout
          end
        end
      end
    end
  end
end
