# frozen_string_literal: true

require 'active_support'
require 'active_support/hash_with_indifferent_access'
require 'active_support/time'

require 'event_summarizer/vendor_result_evaluators/aamva'
require 'event_summarizer/vendor_result_evaluators/instant_verify'
require 'event_summarizer/vendor_result_evaluators/phone_finder'
require 'event_summarizer/vendor_result_evaluators/true_id'
require 'event_summarizer/vendor_result_evaluators/socure_doc_v'

module EventSummarizer
  class IdvMatcher
    IDV_WELCOME_SUBMITTED_EVENT = 'IdV: doc auth welcome submitted'
    IDV_GPO_CODE_SUBMITTED_EVENT = 'IdV: enter verify by mail code submitted'
    IDV_FINAL_RESOLUTION_EVENT = 'IdV: final resolution'
    IDV_IMAGE_UPLOAD_VENDOR_SUBMITTED_EVENT = 'IdV: doc auth image upload vendor submitted'
    IDV_SOCURE_VERIFICATION_DATA_REQUESTED = 'idv_socure_verification_data_requested'
    IDV_PHONE_CONFIRMATION_VENDOR_EVENT = 'IdV: phone confirmation vendor'
    IDV_VERIFY_PROOFING_RESULTS_EVENT = 'IdV: doc auth verify proofing results'
    IPP_ENROLLMENT_STATUS_UPDATED_EVENT = 'GetUspsProofingResultsJob: Enrollment status updated'
    PROFILE_ENCRYPTION_INVALID_EVENT = 'Profile Encryption: Invalid'
    RATE_LIMIT_REACHED_EVENT = 'Rate Limit Reached'

    EVENT_PROPERTIES = ['@message', 'properties', 'event_properties'].freeze

    VENDORS = {
      'TrueID' => {
        id: :trueid,
        name: 'True ID',
        evaluator_module: EventSummarizer::VendorResultEvaluators::TrueId,
      },
      'Socure' => {
        id: :socure_docv,
        name: 'Socure DocV',
        evaluator_module: EventSummarizer::VendorResultEvaluators::SocureDocV,
      },
      'lexisnexis:instant_verify' => {
        id: :instant_verify,
        name: 'Instant Verify',
        evaluator_module: EventSummarizer::VendorResultEvaluators::InstantVerify,
      },
      'lexisnexis:phone_finder' => {
        id: :phone_finder,
        name: 'Phone Finder',
        evaluator_module: EventSummarizer::VendorResultEvaluators::PhoneFinder,
      },
      'aamva:state_id' => {
        id: :aamva,
        name: 'AAMVA',
        evaluator_module: EventSummarizer::VendorResultEvaluators::Aamva,
      },
    }.freeze

    UNKNOWN_VENDOR = {
      id: :unknown,
      name: 'Unknown vendor',
    }.freeze

    IdvAttempt = Data.define(
      :started_at,
      :significant_events,
    ) do
      def initialize(started_at:, significant_events: [])
        super(started_at:, significant_events:)
      end

      def flagged_for_fraud?
        self.significant_events.any? { |e| e.type == :flagged_for_fraud }
      end

      def gpo?
        self.significant_events.any? { |e| e.type == :start_gpo }
      end

      def gpo_pending?
        gpo? && !self.significant_events.any? { |e| e.type == :gpo_code_success }
      end

      def ipp?
        self.significant_events.any? { |e| e.type == :start_ipp }
      end

      def ipp_pending?
        ipp? && !self.significant_events.any? { |e| e.type == :ipp_enrollment_complete }
      end

      def successful?
        self.significant_events.any? do |e|
          e.type == :verified
        end
      end

      def workflow_complete?
        gpo? || ipp? || flagged_for_fraud? || successful?
      end
    end.freeze

    SignificantIdvEvent = Data.define(
      :timestamp,
      :type,
      :description,
    ).freeze

    attr_reader :current_idv_attempt
    attr_reader :idv_attempts
    attr_reader :idv_abandoned_event

    def initialize
      @idv_attempts = []
      @current_idv_attempt = nil
    end

    # @return {Hash,nil}
    def handle_cloudwatch_event(event)
      case event['name']
        when IDV_WELCOME_SUBMITTED_EVENT
          start_new_idv_attempt(event:)

        when IDV_FINAL_RESOLUTION_EVENT

          for_current_idv_attempt(event:) do
            handle_final_resolution_event(event:)
          end

        when IDV_GPO_CODE_SUBMITTED_EVENT
          for_current_idv_attempt(event:) do
            handle_gpo_code_submission(event:)
          end

        when IPP_ENROLLMENT_STATUS_UPDATED_EVENT
          for_current_idv_attempt(event:) do
            handle_ipp_enrollment_status_update(event:)
          end

        when IDV_IMAGE_UPLOAD_VENDOR_SUBMITTED_EVENT
          for_current_idv_attempt(event:) do
            handle_image_upload_vendor_submitted(event:)
          end

        when IDV_SOCURE_VERIFICATION_DATA_REQUESTED
          for_current_idv_attempt(event:) do
            handle_socure_verification_data_requested(event:)
          end

        when IDV_PHONE_CONFIRMATION_VENDOR_EVENT
          for_current_idv_attempt(event:) do
            handle_phone_confirmation_vendor_event(event:)
          end

        when IDV_VERIFY_PROOFING_RESULTS_EVENT
          for_current_idv_attempt(event:) do
            handle_verify_proofing_results_event(event:)
          end

        when PROFILE_ENCRYPTION_INVALID_EVENT
          for_current_idv_attempt(event:) do
            handle_profile_encryption_error(event:)
          end

        when RATE_LIMIT_REACHED_EVENT
          handle_rate_limit_reached(event:)

        else
          if ENV['LOG_UNHANDLED_EVENTS']
            warn "#{event['@timestamp']} #{event['name']}"
          end
      end

      check_for_idv_abandonment(event)
    end

    def finish
      finish_current_idv_attempt

      self.idv_attempts.map { |a| summarize_idv_attempt(a) }.tap do
        idv_attempts.clear
      end
    end

    private

    def add_significant_event(
      timestamp:,
      type:,
      description:
    )
      current_idv_attempt.significant_events << SignificantIdvEvent.new(
        timestamp:,
        type:,
        description:,
      )
    end

    def check_for_idv_abandonment(event)
      return if current_idv_attempt.nil?

      looks_like_idv = /^idv/i.match(event['name'])
      return if !looks_like_idv

      if idv_abandoned_event.nil?
        @idv_abandoned_event = event
        return
      end

      is_a_little_bit_newer = event['@timestamp'] - idv_abandoned_event['@timestamp'] < 1.hour

      if is_a_little_bit_newer
        @idv_abandoned_event = event
      end
    end

    def for_current_idv_attempt(event:, &block)
      if !current_idv_attempt
        warn <<~WARNING
          Encountered #{event['name']} without seeing a '#{IDV_WELCOME_SUBMITTED_EVENT}' event first. 
          This could indicate you need to include earlier events in your request.
        WARNING
        return
      end

      block.call(event)
    end

    def finish_current_idv_attempt
      if !current_idv_attempt.nil?
        looks_like_abandonment =
          !current_idv_attempt.workflow_complete? &&
          !idv_abandoned_event.nil? &&
          idv_abandoned_event['@timestamp'] < 1.hour.ago

        if looks_like_abandonment
          add_significant_event(
            type: :idv_abandoned,
            timestamp: idv_abandoned_event['@timestamp'],
            description: 'User abandoned identity verification',
          )
        end
      end

      idv_attempts << current_idv_attempt if current_idv_attempt
      @current_idv_attempt = nil
      @idv_abandoned_event = nil
    end

    # @return {Hash,nil}
    def handle_final_resolution_event(event:)
      timestamp = event['@timestamp']

      gpo_pending = !!event.dig(
        *EVENT_PROPERTIES,
        'gpo_verification_pending',
      )

      if gpo_pending
        add_significant_event(
          type: :start_gpo,
          timestamp:,
          description: 'User requested a letter to verify by mail',
        )
      end

      ipp_pending = !!event.dig(
        *EVENT_PROPERTIES,
        'in_person_verification_pending',
      )

      if ipp_pending
        add_significant_event(
          type: :start_ipp,
          timestamp:,
          description: 'User entered the in-person proofing flow',
        )
      end

      fraud_review_pending = !!event.dig(
        *EVENT_PROPERTIES,
        'fraud_review_pending',
      )

      if fraud_review_pending
        add_significant_event(
          type: :flagged_for_fraud,
          timestamp:,
          description: 'User was flagged for fraud',
        )
      end

      pending =
        gpo_pending ||
        ipp_pending ||
        fraud_review_pending

      if !pending
        add_significant_event(
          type: :verified,
          timestamp:,
          description: 'User completed identity verification (remote unsupervised flow)',
        )

        finish_current_idv_attempt
      end
    end

    def handle_gpo_code_submission(event:)
      timestamp = event['@timestamp']
      success = event.dig(*EVENT_PROPERTIES, 'success')

      if !success
        add_significant_event(
          type: :gpo_code_failure,
          timestamp:,
          description: 'User entered an invalid GPO code',
        )
        return
      end

      # User successfully entered GPO code. If fraud review is not pending,
      # then they are fully verified
      fraud_review_pending = !!event.dig(
        *EVENT_PROPERTIES,
        'fraud_check_failed',
      )

      fully_verified = !fraud_review_pending

      add_significant_event(
        type: :gpo_code_success,
        timestamp:,
        description: 'User entered a valid GPO code',
      )

      if fully_verified
        add_significant_event(
          type: :verified,
          timestamp:,
          description: 'User completed identity verification',
        )

        finish_current_idv_attempt
      end
    end

    def handle_ipp_enrollment_status_update(event:)
      timestamp = event['@timestamp']
      passed = event.dig(*EVENT_PROPERTIES, 'passed')
      tmx_status = event.dig(*EVENT_PROPERTIES, 'tmx_status')

      return if !passed

      add_significant_event(
        type: :ipp_enrollment_complete,
        timestamp:,
        description: 'User visited the post office and completed IPP enrollment',
      )

      verified = tmx_status != 'review' && tmx_status != 'reject'

      if verified
        current_idv_attempt.significant_events << SignificantIdvEvent.new(
          type: :verified,
          timestamp:,
          description: 'User is fully verified',
        )
      end
    end

    def handle_profile_encryption_error(event:)
      caveats = [
        # TODO these need to check if GPO/IPP were still pending at time of the event
        current_idv_attempt.gpo? ? 'User will not be able to enter a GPO code' : nil,
        current_idv_attempt.ipp? ? 'User will not be able to verify in-person' : nil,
      ].compact

      add_significant_event(
        type: :password_reset,
        timestamp: event['@timestamp'],
        description: [
          'User reset their password and did not provide their personal key.',
          caveats.length > 0 ?
            "User will not be able to #{caveats.join(' or ')}" :
            nil,
        ].compact.join(' '),
      )
    end

    def handle_rate_limit_reached(event:)
      limiters = {
        'idv_doc_auth' => 'Doc Auth',
      }

      limiter_type = event.dig(*EVENT_PROPERTIES, 'limiter_type')

      limit_name = limiters[limiter_type]

      return if limit_name.blank?

      timestamp = event['@timestamp']

      for_current_idv_attempt(event:) do
        add_significant_event(
          type: :rate_limited,
          timestamp:,
          description: "Rate limited for #{limit_name}",
        )
      end
    end

    def handle_image_upload_vendor_submitted(event:)
      timestamp = event['@timestamp']
      success = event.dig(*EVENT_PROPERTIES, 'success')
      doc_type = event.dig(*EVENT_PROPERTIES, 'DocClassName')

      if success
        prior_failures = current_idv_attempt.significant_events.count do |e|
          e.type == :failed_document_capture
        end
        attempts = prior_failures > 0 ? "after #{prior_failures} tries" : 'on the first attempt'

        add_significant_event(
          timestamp:,
          type: :passed_document_capture,
          description:
            "User successfully verified their #{doc_type.downcase} via TrueID #{attempts}",
        )
        return
      end

      prev_count = current_idv_attempt.significant_events.count

      alerts = event.dig(*EVENT_PROPERTIES, 'processed_alerts')
      alerts['success'] = false
      alerts['vendor_name'] = event.dig(*EVENT_PROPERTIES, 'vendor')
      alerts['document_type'] = doc_type.downcase

      add_events_for_failed_vendor_result(
        alerts,
        timestamp:,
      )

      any_events_added = current_idv_attempt.significant_events.count > prev_count

      if !any_events_added
        add_significant_event(
          timestamp:,
          type: :failed_document_capture,
          description: "User failed to verify their #{doc_type.downcase} via TrueID (check logs for reason)", # rubocop:disable Layout/LineLength
        )
      end
    end

    def handle_socure_verification_data_requested(event:)
      timestamp = event['@timestamp']
      success = event.dig(*EVENT_PROPERTIES, 'success')
      doc_type = event.dig(*EVENT_PROPERTIES, 'document_metadata', 'type')

      if success
        prior_failures = current_idv_attempt.significant_events.count do |e|
          e.type == :failed_document_capture
        end
        attempts = prior_failures > 0 ? "after #{prior_failures} tries" : 'on the first attempt'

        add_significant_event(
          timestamp:,
          type: :passed_document_capture,
          description:
            "User successfully verified their #{doc_type.downcase} via Socure DocV #{attempts}",
        )
        return
      end

      prev_count = current_idv_attempt.significant_events.count

      alerts = ActiveSupport::HashWithIndifferentAccess.new
      alerts[:reason_codes] = socure_reason_codes(event)
      alerts[:success] = false
      alerts[:vendor_name] = event.dig(*EVENT_PROPERTIES, 'vendor')
      alerts[:document_type] = doc_type.downcase

      add_events_for_failed_vendor_result(
        alerts,
        timestamp:,
      )

      any_events_added = current_idv_attempt.significant_events.count > prev_count

      if !any_events_added
        add_significant_event(
          timestamp:,
          type: :failed_document_capture,
          description: "User failed to verify their #{doc_type.downcase} via Socure DocV (check logs for reason)", # rubocop:disable Layout/LineLength
        )
      end
    end

    def socure_reason_codes(event)
      event.dig(*EVENT_PROPERTIES, 'reason_codes') || []
    end

    def handle_phone_confirmation_vendor_event(event:)
      timestamp = event['@timestamp']
      success = event.dig(*EVENT_PROPERTIES, 'success')

      if success
        add_significant_event(
          timestamp:,
          type: :passed_phone_finder,
          description: 'Phone Finder check succeeded',
        )

        return
      end

      add_events_for_failed_vendor_result(event.dig(*EVENT_PROPERTIES), timestamp:)
    end

    def handle_verify_proofing_results_event(event:)
      timestamp = event['@timestamp']
      success = event.dig(*EVENT_PROPERTIES, 'success')

      if success
        # We only really care about passing identity resolution if the
        # user previously failed in this attempt

        prior_failures = current_idv_attempt.significant_events.count do |e|
          e.type == :failed_identity_resolution
        end

        if prior_failures > 0
          # TODO: What changed that made them be able to pass?

          add_significant_event(
            timestamp:,
            type: :passed_identity_resolution,
            description: "User passed identity resolution after #{prior_failures + 1} tries",
          )
        end

        return
      end

      # Failing identity resolution is where it gets interesting

      prev_count = current_idv_attempt.significant_events.count

      add_events_for_failed_vendor_result(
        event.dig(
          *EVENT_PROPERTIES, 'proofing_results', 'context', 'stages', 'resolution'
        ),
        timestamp:,
      )

      add_events_for_failed_vendor_result(
        event.dig(
          *EVENT_PROPERTIES, 'proofing_results', 'context', 'stages', 'residential_address'
        ),
        timestamp:,
      )

      add_events_for_failed_vendor_result(
        event.dig(
          *EVENT_PROPERTIES, 'proofing_results', 'context', 'stages', 'state_id'
        ),
        timestamp:,
      )

      any_events_added = current_idv_attempt.significant_events.count > prev_count

      if !any_events_added
        add_significant_event(
          timestamp:,
          type: :failed_identity_resolution,
          description: 'User failed identity resolution (check logs for reason)',
        )
      end
    end

    def add_events_for_failed_vendor_result(result, timestamp:)
      return if result['success']

      vendor_name = result['vendor_name'] || result.dig('vendor', 'vendor_name')
      vendor = VENDORS[vendor_name] || UNKNOWN_VENDOR
      evaluator = vendor[:evaluator_module]

      if !evaluator.present?
        add_significant_event(
          type: :"#{vendor[:id]}_request_failed",
          timestamp:,
          description: "Request to #{vendor[:name]} failed.",
        )
        return
      end

      evaluation = evaluator.evaluate_result(result)
      add_significant_event(**evaluation, timestamp:) if evaluation
    end

    # @return {IdvAttempt,nil} The previous IdvAttempt (if any)
    def start_new_idv_attempt(event:)
      finish_current_idv_attempt if current_idv_attempt

      @current_idv_attempt = IdvAttempt.new(
        started_at: event['@timestamp'],
      )
    end

    def summarize_idv_attempt(attempt)
      type = :idv
      title = 'Identity verification started'
      attributes = attempt.significant_events.map do |e|
        {
          type: e.type,
          timestamp: e.timestamp,
          description: e.description,
        }
      end

      if attempt.successful?
        title = 'Identity verified'
      end

      {
        started_at: attempt.started_at,
        title:,
        type:,
        attributes:,
      }
    end
  end
end
