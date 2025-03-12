# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      class VerificationRequest < Request
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
            account_email: applicant[:email],
            account_first_name: applicant[:first_name] || '',
            account_last_name: applicant[:last_name] || '',
            account_telephone: '', # applicant[:phone], decision was made not to send phone
            account_drivers_license_number: applicant[:state_id_number]&.gsub(/\W/, '') || '',
            account_drivers_license_type: applicant[:state_id_number] ? 'us_dl' : '',
            account_drivers_license_issuer: applicant[:state_id_jurisdiction].to_s.strip || '',
            customer_event_type: applicant[:workflow],
            event_type: 'ACCOUNT_CREATION',
            policy: config.ddp_policy,
            service_type: 'all',
            session_id: applicant[:threatmetrix_session_id],
            national_id_number: applicant[:ssn]&.gsub(/\D/, '') || '',
            national_id_type: applicant[:ssn] ? 'US_SSN' : '',
            input_ip_address: applicant[:request_ip],
            local_attrib_1: applicant[:uuid_prefix] || '',
            local_attrib_3: applicant[:uuid],
          }.to_json
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
