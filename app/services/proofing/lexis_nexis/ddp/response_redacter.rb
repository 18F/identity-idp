# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      class ResponseRedacter
        ALLOWED_RESPONSE_FIELDS = %w[
          account_email_assert_history
          account_email_first_seen
          account_email_last_event
          account_email_last_update
          account_email_result
          account_email_score
          account_email_worst_score
          account_address_assert_history
          account_address_country
          account_address_first_seen
          account_address_last_event
          account_address_last_update
          account_address_score
          account_address_state
          account_lex_id
          account_lex_id_first_seen
          account_lex_id_last_event
          account_lex_id_last_update
          account_lex_id_region
          account_lex_id_result
          account_lex_id_score
          account_lex_id_worst_score
          account_name_assert_history
          account_name_first_seen
          account_name_last_event
          account_name_last_update
          account_name_result
          account_name_score
          account_name_worst_score
          api_call_datetime
          api_caller_ip
          api_type
          api_version
          bb_assessment
          bb_assessment_rating
          bb_bot_rating
          bb_bot_score
          bb_fraud_rating
          bb_fraud_score
          champion_request_duration
          device_first_seen
          device_id_confidence
          device_last_event
          device_last_update
          device_match_result
          device_score
          device_worst_score
          digital_id
          digital_id_confidence
          digital_id_confidence_rating
          digital_id_first_seen
          digital_id_last_event
          digital_id_last_update
          digital_id_result
          digital_id_trust_score
          digital_id_trust_score_rating
          digital_id_trust_score_reason_code
          digital_id_trust_score_summary_reason_code
          emailage.emailriskscore.billaddresstofullnameconfidence
          emailage.emailriskscore.billaddresstolastnameconfidence
          emailage.emailriskscore.billriskcountry
          emailage.emailriskscore.correlationid
          emailage.emailriskscore.disdescription
          emailage.emailriskscore.domain_creation_days
          emailage.emailriskscore.domainage
          emailage.emailriskscore.domaincategory
          emailage.emailriskscore.domaincountry
          emailage.emailriskscore.domaincountrymatch
          emailage.emailriskscore.domainexists
          emailage.emailriskscore.domainrelevantinfo
          emailage.emailriskscore.domainrelevantinfoid
          emailage.emailriskscore.domainriskcountry
          emailage.emailriskscore.domainrisklevel
          emailage.emailriskscore.domainrisklevelid
          emailage.emailriskscore.eaadvice
          emailage.emailriskscore.eaadviceid
          emailage.emailriskscore.eareason
          emailage.emailriskscore.eareasonid
          emailage.emailriskscore.eariskband
          emailage.emailriskscore.eariskbandid
          emailage.emailriskscore.eascore
          emailage.emailriskscore.eastatusid
          emailage.emailriskscore.emailage
          emailage.emailriskscore.email_creation_days
          emailage.emailriskscore.emailexists
          emailage.emailriskscore.emailtobilladdressconfidence
          emailage.emailriskscore.emailtofullnameconfidence
          emailage.emailriskscore.emailtoipconfidence
          emailage.emailriskscore.emailtolastnameconfidence
          emailage.emailriskscore.first_seen_days
          emailage.emailriskscore.firstverificationdate
          emailage.emailriskscore.fraudrisk
          emailage.emailriskscore.ip_risklevel
          emailage.emailriskscore.ip_riskreason
          emailage.emailriskscore.iptobilladdressconfidence
          emailage.emailriskscore.iptofullnameconfidence
          emailage.emailriskscore.iptolastnameconfidence
          emailage.emailriskscore.namematch
          emailage.emailriskscore.overalldigitalidentityscore
          emailage.emailriskscore.phone_status
          emailage.emailriskscore.responsestatus.errorcode
          emailage.emailriskscore.responsestatus.status
          emailage.emailriskscore.shipforward
          emailage.emailriskscore.status
          emailage.emailriskscore.totalhits
          emailage.emailriskscore.uniquehits
          enabled_services
          event_datetime
          event_type
          fraudpoint.conversation_id
          fraudpoint.friendly_fraud_index
          fraudpoint.manipulated_identity_index
          fraudpoint.product_status
          fraudpoint.transaction_reason_code
          fraudpoint.risk_indicators_codes
          fraudpoint.risk_indicators_descriptions
          fraudpoint.score
          fraudpoint.stolen_identity_index
          fraudpoint.suspicious_activity_index
          fraudpoint.synthetic_identity_index
          fraudpoint.transaction_status
          fraudpoint.vulnerable_victim_index
          fuzzy_device_first_seen
          fuzzy_device_id_confidence
          fuzzy_device_last_event
          fuzzy_device_last_update
          fuzzy_device_match_result
          fuzzy_device_result
          fuzzy_device_score
          fuzzy_device_worst_score
          http_connection_type
          http_referer_domain
          input_ip_assert_history
          input_ip_connection_type
          input_ip_first_seen
          input_ip_last_event
          input_ip_last_update
          input_ip_score
          input_ip_worst_score
          national_id_first_seen
          national_id_last_event
          national_id_last_update
          national_id_score
          national_id_type
          national_id_worst_score
          org_id
          policy
          policy_details_api
          policy_engine_version
          policy_score
          page_time_on
          primary_industry
          private_browsing
          profile_api_timedelta
          profile_connection_type
          profiling_datetime
          profiling_delta
          proxy_score
          reason_code
          request_duration
          request_id
          request_result
          review_status
          risk_rating
          secondary_industry
          service_type
          session_id
          session_id_query_count
          summary_risk_score
          time_zone
          time_zone_dst_offset
          timezone_name
          tmx_reason_code
          tmx_risk_rating
          tmx_summary_reason_code
          tmx_variables
          tps_datetime
          tps_duration
          tps_error
          tps_result
          tps_type
          tps_vendor
          tps_was_timeout
          true_ip_score
          true_ip_worst_score
          unknown_session
        ].freeze

        # @param [Hash, nil] parsed JSON response body
        def self.redact(hash)
          return { error: 'TMx response body was empty' } if hash.nil?
          return { error: 'TMx response body was malformed' } unless hash.is_a? Hash
          filtered_response_h = hash.slice(*ALLOWED_RESPONSE_FIELDS)
          unfiltered_keys = hash.keys - filtered_response_h.keys
          unfiltered_keys.each do |key|
            filtered_response_h[key] = '[redacted]'
          end
          filtered_response_h
        end
      end
    end
  end
end
