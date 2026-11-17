# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      module Requests
        class ThreatMetrixRequest < Request
          MINIMUM_SSN_HASH_KEY_BYTES = 32

          private

          def build_request_body
            normalized_ssn = SsnFormatter.normalize(applicant[:ssn])

            request_body = {
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
              national_id_number: normalized_ssn,
              national_id_type: normalized_ssn.present? ? 'US_SSN' : '',
              input_ip_address: applicant[:request_ip],
              local_attrib_1: applicant[:uuid_prefix] || '',
              local_attrib_3: applicant[:uuid],
            }

            hashed_ssn = ssn_hash(normalized_ssn)
            request_body[:ssn_hash] = hashed_ssn if hashed_ssn

            request_body.to_json
          end

          def ssn_hash(normalized_ssn)
            return if normalized_ssn.blank?

            hmac_secret_key =
              IdentityConfig.store.lexisnexis_threatmetrix_ssn_hash_hmac_secret_key
            return if hmac_secret_key.blank?

            if hmac_secret_key.bytesize < MINIMUM_SSN_HASH_KEY_BYTES
              raise 'ThreatMetrix SSN hash key must be at least 32 bytes'
            end

            OpenSSL::HMAC.hexdigest('SHA512', hmac_secret_key, normalized_ssn)
          end

          def metric_name
            'lexis_nexis_ddp_threat_metrix'
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
end
