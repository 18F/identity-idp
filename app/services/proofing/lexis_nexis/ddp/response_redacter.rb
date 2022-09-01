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
          emailage.emailriskscore.billriskcountry
          emailage.emailriskscore.correlationid
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
          emailage.emailriskscore.emailexists
          emailage.emailriskscore.first_seen_days
          emailage.emailriskscore.firstverificationdate
          emailage.emailriskscore.fraudrisk
          emailage.emailriskscore.namematch
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
          org_id
          policy
          policy_details_api
          policy_engine_version
          policy_score
          primary_industry
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
          unknown_session
        ]

        # @param [Hash] body
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
