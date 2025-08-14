# frozen_string_literal: true

require 'csv'
begin
  require 'reporting/cloudwatch_client'
  require 'reporting/cloudwatch_query_quoting'
  require 'reporting/command_line_options'
rescue LoadError => e
  warn 'could not load paths, try running with "bundle exec rails runner"'
  raise e
end

module Reporting
  class FraudBlocksProofingRateReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :time_range

    module Events
      # this for successful ipp
      SUCCESSFUL_IPP = 'GetUspsProofingResultsJob: Enrollment status updated'
      # THESE FOR SUSPECTED FRAUD BLOCKS --------------------------------
      # note: events in the key friction points are also used in the suspected fraud blocks queries as well.
      IDV_PHONE_CONF_VENDOR = 'IdV: phone confirmation vendor'
      # THESE FOR KEY FRICTION POINTS -----------------------------------
      # these two for api connection fails
      IDV_DOC_AUTH_VERIFY_PROOFING_RESULTS = 'IdV: doc auth verify proofing results'
      IDV_PHONE_RECORD_VISITED = 'IdV: phone of record visited'
      # these for verification code not received
      IDV_PHONE_CONF_OTP_VISITED = 'IdV: phone confirmation otp visited'
      IDV_PHONE_CONF_OTP_SUBMITTED = 'IdV: phone confirmation otp submitted'
      IDV_ENTER_PASSWORD_VISITED = 'IdV: enter password visited'
      # these for doc/selfie ux challenges - Lexis
      IDV_FRONT_IMAGE_ADDED = 'Frontend: IdV: front image added'
      IDV_BACK_IMAGE_ADDED = 'Frontend: IdV: back image added'
      IDV_DOC_AUTH_IMAGE_UPLOAD_VENDOR_SUBMITTED = 'IdV: doc auth image upload vendor submitted'
      IDV_DOC_AUTH_SSN_VISITED = 'IdV: doc auth ssn visited'
      # doc/selfie ux challenges - Socure
      IDV_SOCURE_VERIFICATION_DATA_REQUESTED = 'idv_socure_verification_data_requested'
      # -------------------------------------------------------------------

      def self.all_events
        constants.map { |c| const_get(c) }
      end
    end

    # @param [Range<Time>] time_range
    def initialize(
      time_range:,
      verbose: false,
      progress: false,
      slice: 6.hours,
      threads: 1
    )
      @time_range = time_range
      @verbose = verbose
      @progress = progress
      @slice = slice
      @threads = threads
    end

    def verbose?
      @verbose
    end

    def progress?
      @progress
    end

    def as_emailable_reports
      [
        # [
        #   Reporting::EmailableReport.new(
        #     title: "Proofing Success Metrics #{stats_month}", #Proofing Success comes from IdP
        #     table: proofing_success_metrics_table,
        #     filename: 'proofing_success_metrics',
        #   ),
        Reporting::EmailableReport.new(
          title: "Suspected Fraud Blocks Metrics #{stats_month}", # Suspected Fraud Related Blocks
          table: suspected_fraud_blocks_metrics_table,
          filename: 'suspected_fraud_blocks_metrics',
        ),
        Reporting::EmailableReport.new(
          title: "Key Points of User Friction Metrics #{stats_month}", # Key Points of User Friction
          table: key_points_user_friction_metrics_table,
          filename: 'key_points_user_friction_metrics',
        ),
        Reporting::EmailableReport.new(
          title: "Successful IPP User Metrics #{stats_month}", # Successful IPP
          table: successful_ipp_table,
          filename: 'successful_ipp',
        ),
      ]
    end

    # this will come from IdP and thus needs to be modified
    # def proofing_success_metrics_table #table for Proofing Success
    #   [
    #     ['Metric', 'Total', 'Range Start', 'Range End'],
    #     ['Identity Verified Users', lg99_unique_users_count.to_s, time_range.begin.to_s,
    #      time_range.end.to_s],
    #     ['Idv Rate w/Preverified Users', lg99_unique_users_count.to_s, time_range.begin.to_s,
    #     time_range.end.to_s],
    #   ]
    # rescue Aws::CloudWatchLogs::Errors::ThrottlingException => err
    #   [
    #     ['Error', 'Message'],
    #     [err.class.name, err.message],
    #   ]
    # end

    def suspected_fraud_blocks_metrics_table # table Suspected Fraud Related Blocks
      # TODO: NEED TO UPDATE THE TOTAL FOR ALL THESE ENTRIES-----------------------------
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        [
          'Authentic Drivers License',
          authentic_drivers_license.to_s, # will need to be a calculation because we add lexis and socure together
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Valid Drivers License #',
          valid_drivers_license_number.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Facial Matching Check',
          facial_matching_check.to_s, # will need to be a calculation because we add lexis and socure together
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Identity Not Found',
          identity_not_found.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Address / Occupancy Match',
          address_occupancy_match.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Social Security Number Match',
          social_security_number_match.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Date of Birth Match',
          dob_match.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Deceased Check',
          dead_check.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Phone Account Ownership',
          phone_account_ownership.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Device and Behavior Fraud Signals',
          device_behavior_fraud_signals.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        # TODO: END ----------------------------------------------------------------------
      ]
    end

    def reinstated_metrics_table # table Key Points of User Friction
      # TODO: NEED TO UPDATE THE TOTAL FOR ALL THESE ENTRIES-----------------------------
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        [
          'Document / selfie upload UX challenge', # will need to be a calculation because we add lexis and socure together
          doc_selfie_ux_challenge_count.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Verification code not received',
          verification_code_not_received_count.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'API connection fails',
          api_connection_fails.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        # TODO: END ----------------------------------------------------------------------
      ]
    end

    def successful_ipp_table # table for successful ipp
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        [
          'Successful IPP',
          successful_ipp_users_count.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
      ]
    end

    def stats_month
      time_range.begin.strftime('%b-%Y')
    end

    # QUESTION: I NEED TO MODIFY THIS PART AND NEED HELP DOING SO ? ----------------------
    # def data
    #   @data ||= begin
    #     event_users = Hash.new do |h, uuid|
    #       h[uuid] = Set.new
    #     end

    #     fetch_results.each do |row|
    #       event_users[row['name']] << row['user_id']
    #     end

    #     event_users
    #   end
    # end
    # TODO: END --------------------------------------------------------------------------
    def verification_code_not_received_results
      cloudwatch_client.fetch(
        verification_code_not_received_query:, from: time_range.begin,
        to: time_range.end
      )
    end

    def fetch_api_connection_fails_results
      cloudwatch_client.fetch(
        api_connection_fails_query:, from: time_range.begin,
        to: time_range.end
      )
    end

    def fetch_successful_ipp_results
      cloudwatch_client.fetch(successful_ipp_query:, from: time_range.begin, to: time_range.end)
    end

    # ---------------------------------------------------------------------------------------
    def verification_code_not_received_query
      params = {
        issuers: quote(issuers),
        idv_phone_conf_otp_visited: quote(Events::IDV_PHONE_CONF_OTP_VISITED),
        idv_phone_conf_otp_submitted: quote(Events::IDV_PHONE_CONF_OTP_SUBMITTED),
        idv_enter_password_visited: quote(Events::IDV_ENTER_PASSWORD_VISITED),
      }
      format(<<~QUERY, params)
        # Verification code not received
        filter name in [%{idv_phone_conf_otp_visited}, %{idv_phone_conf_otp_submitted}, %{idv_enter_password_visited}]
        | filter properties.service_provider in [%{issuers}]
        | fields (name = %{idv_phone_conf_otp_visited}) as @code_sent,
            (name = %{idv_phone_conf_otp_submitted}) as @code_submitted,
            (name = %{idv_enter_password_visited}) as @code_successfully_submitted
        | stats max(@code_sent) as code_sent,
                max(@code_submitted) as code_submitted,
                max(@code_successfully_submitted) as code_successfully_submitted
                by properties.user_id
        | filter code_successfully_submitted=0
        | fields code_sent and code_submitted=0 as code_error 
        | stats sum(code_error)
      QUERY
    end

    def api_connection_fails_query
      params = {
        issuers: quote(issuers),
        idv_doc_auth_verify_proofing_results: quote(Events::IDV_DOC_AUTH_VERIFY_PROOFING_RESULTS),
        idv_phone_record_visited: quote(Events::IDV_PHONE_RECORD_VISITED),
      }

      format(<<~QUERY, params)
        filter name in [%{idv_doc_auth_verify_proofing_results}, %{idv_phone_record_visited}]
        | filter properties.service_provider = %{issuers}
        | fields @message,
            (@message like /AAMVA raised Faraday/) as aamva_timeout_error_field,
            (@message like /Lexis Nexis request raised Faraday/) as ln_timeout_error,
            (@message like /Unexpected status code in response/) as state_timeout_error,
            # (@message like /Socure raised Faraday/) as socure_timeout_error, #todo: find what exact phrasing will be for socure kyc or any socure (ask team charity)
            (name = 'IdV: phone of record visited') as ID_resolution_success

        | fields jsonParse(@message) as message
        | unnest message.properties.event_properties into event_properties
        | unnest event_properties.opted_in_to_in_person_proofing into ipp
        | unnest event_properties.proofing_results into proofing_results
        | unnest proofing_results.context into context
        | unnest context.stages into stages
        | unnest stages.state_id into state_id
        | unnest state_id.exception into exception
        | unnest context.should_proof_state_id into should_proof_state_id

        | fields coalesce(should_proof_state_id, 0) as should_proof_state_id_fill_na
        | fields coalesce(exception, 'none') as exception_fill_na

        | filter ipp = 0

        | stats 
            max(ID_resolution_success) as ID_resolution_success_num,  
            max(should_proof_state_id_fill_na) as should_proof_state_id_fill_na_num,
            max(aamva_timeout_error_field) as aamva_fail,
            max(ln_timeout_error) as ln_fail,
            max(state_timeout_error) as state_timeout_fail
            by properties.user_id

        | filter ID_resolution_success_num=0 and (ln_fail=1 or aamva_fail=1 or state_timeout_fail=1) 

        | stats
            sum(aamva_fail) as AAMVA_fail_count,
            sum(ln_fail) as LN_timeout_fail_count,
            sum(state_timeout_fail) as state_timeout_fail_count,
            count(*) as api_user_fail    

      QUERY
    end

    def successful_ipp_query
      params = {
        issuers: quote(issuers),
        successful_ipp: quote(Events::SUCCESSFUL_IPP),
      }

      format(<<~QUERY, params)
        filter name in %{successful_ipp}
        | fields 
            (name = %{successful_ipp} and 
            properties.event_properties.passed=1 
            and properties.event_properties.issuer=%{issuers}) as @ipp_verified
        | filter @ipp_verified=1

        |stats
            sum(@ipp_verified) as IPP_successfully_proofed_user_counts

      QUERY
    end
    # ---------------------------------------------------------------------------------------

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        num_threads: @threads,
        ensure_complete_logs: true,
        slice_interval: @slice,
        progress: progress?,
        logger: verbose? ? Logger.new(STDERR) : nil,
      )
    end

    # HELP WITH THESE (DO I EVEN NEED THEM?)---------------------------------------
    # api_connection_fails # help here
    def api_connection_fails
      @api_connection_fails ||= data[Events::IDV_DOC_AUTH_VERIFY_PROOFING_RESULTS,
                                     IDV_PHONE_RECORD_VISITED]
    end

    # successful ipp users
    def successful_ipp_users_count
      @successful_ipp_users_count ||= data[Events::SUCCESSFUL_IPP]
    end
    # TODO: END ---------------------------------------------------------------------
  end
end
