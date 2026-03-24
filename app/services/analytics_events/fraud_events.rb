# frozen_string_literal: true

module AnalyticsEvents
  module FraudEvents

    # @param [Boolean] success Check whether threatmetrix succeeded properly.
    # @param [String] transaction_id Vendor-specific transaction ID for the request.
    # @param [String, nil] client Client user was directed from when creating account
    # @param [array<String>, nil] errors error response from api call
    # @param [String, nil] exception Error exception from api call
    # @param [Boolean] timed_out set whether api call timed out
    # @param [String] review_status TMX decision on the user
    # @param [String] account_lex_id LexID associated with the response.
    # @param [String] session_id Session ID associated with response
    # @param [Hash] response_body total response body for api call
    # Result when threatmetrix is completed for account creation and result
    def account_creation_tmx_result(
      client:,
      success:,
      errors:,
      exception:,
      timed_out:,
      transaction_id:,
      review_status:,
      account_lex_id:,
      session_id:,
      response_body:,
      **extra
    )
      track_event(
        :account_creation_tmx_result,
        client:,
        success:,
        errors:,
        exception:,
        timed_out:,
        transaction_id:,
        review_status:,
        account_lex_id:,
        session_id:,
        response_body:,
        **extra,
      )
    end

    # @param [DateTime] fraud_rejection_at Date when profile was rejected
    # Tracks when a profile is automatically rejected due to being under review for 30 days
    def automatic_fraud_rejection(fraud_rejection_at:, **extra)
      track_event(
        'Fraud: Automatic Fraud Rejection',
        fraud_rejection_at: fraud_rejection_at,
        **extra,
      )
    end

    def device_profiling_failed_visited
      track_event(:device_profiling_failed_visited)
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] errors Errors resulting from form validation
    # @param [String] exception
    # @param [String] profile_fraud_review_pending_at
    # @param [Integer] profile_age_in_seconds How many seconds have passed since profile created
    # The user was passed by manual fraud review
    def fraud_review_passed(
      success:,
      errors:,
      exception:,
      profile_fraud_review_pending_at:,
      profile_age_in_seconds:,
      **extra
    )
      track_event(
        'Fraud: Profile review passed',
        success: success,
        errors: errors,
        exception: exception,
        profile_fraud_review_pending_at: profile_fraud_review_pending_at,
        profile_age_in_seconds: profile_age_in_seconds,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] errors Errors resulting from form validation
    # @param [String] exception
    # @param [String] profile_fraud_review_pending_at
    # @param [Integer] profile_age_in_seconds How many seconds have passed since profile created
    # The user was rejected by manual fraud review
    def fraud_review_rejected(
      success:,
      errors:,
      exception:,
      profile_fraud_review_pending_at:,
      profile_age_in_seconds:,
      **extra
    )
      track_event(
        'Fraud: Profile review rejected',
        success: success,
        errors: errors,
        exception: exception,
        profile_fraud_review_pending_at: profile_fraud_review_pending_at,
        profile_age_in_seconds: profile_age_in_seconds,
        **extra,
      )
    end

    # The JSON body of the response returned from Hybrid Threatmetrix. PII has been removed.
    # @param [Hash] response_body The response body returned by Hybrid ThreatMetrix
    def idv_threatmetrix_hybrid_mobile_response_body(
      response_body: nil,
      **extra
    )
      track_event(
        :idv_threatmetrix_hybrid_mobile_response_body,
        response_body: response_body,
        **extra,
      )
    end

    # The JSON body of the response returned from Threatmetrix. PII has been removed.
    # @param [Hash] response_body The response body returned by ThreatMetrix
    def idv_threatmetrix_response_body(
      response_body: nil,
      **extra
    )
      track_event(
        :idv_threatmetrix_response_body,
        response_body: response_body,
        **extra,
      )
    end

    # The user ended up at the "Verify info" screen without a Threatmetrix session id.
    def idv_verify_info_missing_threatmetrix_session_id(**extra)
      track_event(:idv_verify_info_missing_threatmetrix_session_id, **extra)
    end
  end
end
