# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      class VerificationRequest < Request
        private

        def build_request_body
          if config.ddp_policy == IdentityConfig.store.lexisnexis_authentication_threatmetrix_policy
            default_body.to_json
          else
            default_body.merge(proofing_request_body).to_json
          end
        end

        def default_body
          {
            api_key: config.api_key,
            org_id: config.org_id,
            account_email: applicant[:email],
            event_type: 'ACCOUNT_CREATION',
            policy: config.ddp_policy,
            service_type: 'all',
            session_id: applicant[:threatmetrix_session_id],
            input_ip_address: applicant[:request_ip],
          }
        end

        def proofing_request_body
          {
            account_address_street1: applicant[:address1],
            account_address_street2: applicant[:address2] || '',
            account_address_city: applicant[:city],
            account_address_state: applicant[:state],
            account_address_country: 'US',
            account_address_zip: applicant[:zipcode],
            account_date_of_birth: applicant[:dob] ?
              Date.parse(applicant[:dob]).strftime('%Y%m%d') : '',
            account_email: applicant[:email],
            account_first_name: applicant[:first_name],
            account_last_name: applicant[:last_name],
            account_telephone: '', # applicant[:phone], decision was made not to send phone
            account_drivers_license_number: applicant[:state_id_number]&.gsub(/\W/, ''),
            account_drivers_license_type: 'us_dl',
            account_drivers_license_issuer: applicant[:state_id_jurisdiction].to_s.strip,
            national_id_number: applicant[:ssn].gsub(/\D/, ''),
            national_id_type: 'US_SSN',
            local_attrib_1: applicant[:uuid_prefix],
          }
        end

        def metric_name
          'lexis_nexis_ddp'
        end

        def url_request_path
          '/api/session-query'
        end

        def timeout
          IdentityConfig.store.lexisnexis_threatmetrix_timeout
        end
      end
    end
  end
end
