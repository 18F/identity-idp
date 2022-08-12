module Proofing
  module LexisNexis
    module Ddp
      class VerificationRequest < Request
        private

        def build_request_body
          {
            api_key: config.api_key,
            org_id: config.org_id,
            account_address_street1: applicant[:address1],
            account_address_street2: applicant[:address2] || '',
            account_address_city: applicant[:city],
            account_address_state: applicant[:state],
            account_address_country: 'US',
            account_address_zip: applicant[:zipcode].match(/^\d{5}/).to_s,
            account_date_of_birth: Date.parse(applicant[:dob]).strftime('%Y%m%d'),
            account_email: applicant[:email],
            account_first_name: applicant[:first_name],
            account_last_name: applicant[:last_name],
            account_telephone: applicant[:phone],
            drivers_license_number_hash: applicant[:state_id_number] ?
              OpenSSL::Digest::SHA256.hexdigest(applicant[:state_id_number].gsub(/\W/, '')) : '',
            event_type: 'ACCOUNT_CREATION',
            service_type: 'all',
            session_id: applicant[:threatmetrix_session_id] || 'UNIQUE_SESSION_ID',
            ssn_hash: OpenSSL::Digest::SHA256.hexdigest(applicant[:ssn].gsub(/\D/, '')),
          }.to_json
        end

        def metric_name
          'lexis_nexis_ddp'
        end

        def url_request_path
          '/api/session-query'
        end

        def timeout
          IdentityConfig.store.lexisnexis_ddp_timeout
        end
      end
    end
  end
end
