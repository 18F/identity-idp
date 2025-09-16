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
  class TestIdentityVerificationOutcomesReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :issuers, :time_range

    module Events
      # this for successful ipp
      SUCCESSFUL_IPP = 'GetUspsProofingResultsJob: Enrollment status updated'
      # THESE FOR SUSPECTED FRAUD BLOCKS --------------------------------
      # note: events in the key friction points are also used in the suspected fraud blocks
      # queries as well.
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

      # these are for retriving values for the tables
      API_CONNECTION_FAILS = 'api_connection_fails'
      DOC_SELFIE_UX_CHALLENGE_LEXIS = 'doc_selfie_ux_challenge_lexis'
      DOC_SELFIE_UX_CHALLENGE_SOCURE = 'doc_selfie_ux_challenge_socure'
      VERF_CODE_NOT_RECIEVED = 'verification_code_not_received'
      DOC_AUTH_FACIAL_LEXIS = 'doc_auth_facial_lexis'
      DOC_AUTH_FACIAL_SOCURE = 'doc_auth_facial_socure'
      SELFIE_FAIL_LEXIS = 'selfie_fail_lexis'
      SELFIE_FAIL_SOCURE = 'selfie_fail_socure'
      ADDRESS_OCCUPANCY = 'address_occupancy'
      SSN = 'ssn'
      DOB = 'dob'
      DEAD = 'dead'
      IDENTITY_NOT_FOUND = 'identity_not_found'
      VAILD_DRIVERS_LICENSE_NUMBER = 'valid_drivers_license_number'
      PHONE_ACCOUNT_OWNERSHIP = 'phone_account_ownership'
      DEVICE_BEHAVIOR_FRAUD_SIGNALS = 'device_behavior_fraud_signals'
      SUCCESSFUL_IPP_OUTPUT = 'successful_ipp_output'

      IAL2 = 'ial2'
      TROUBLESHOOTING_OPTION = 'IdV: verify in person troubleshooting option clicked'
      IPP_BARCODE_OUTPUT = 'ipp_barcode_output'
      IPP_READY = 'IdV: in person ready to verify visited'
      # -------------------------------------------------------------------

      def self.all_events
        constants.map { |c| const_get(c) }
      end
    end

    # @param [Range<Time>] time_range
    def initialize(
      issuers:,
      time_range:,
      verbose: false,
      progress: true,
      slice: 1.day,
      threads: 5
    )
      @issuers = issuers
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
        Reporting::EmailableReport.new(
          title: 'Overview',
          table: overview_table,
          filename: 'overview',
        ),
        Reporting::EmailableReport.new(
          title: "Proofing Success Metrics #{stats_month}", # Proofing Success comes from IdP
          table: proofing_success_metrics_table,
          filename: 'proofing_success_metrics',
        ),
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

    # overview table
    def overview_table
      [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        # This needs to be Date.today so it works when run on the command line
        ['Report Generated', Time.zone.today.to_s],
        ['Issuer', issuers.present? ? issuers.join(', ') : 'All Issuers'],
      ]
    end

    # this will come from IdP and thus needs to be modified
    # table for Proofing Success -------------------------------------------------------
    def proofing_success_metrics_table
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        ['Identity Verified Users', ial2.to_s, time_range.begin.to_s,
         time_range.end.to_s],
        ['Idv Rate w/Preverified Users', idv_rate.to_s, time_range.begin.to_s,
         time_range.end.to_s],
      ]
    end

    # table Suspected Fraud Related Blocks ----------------------------------------------
    def suspected_fraud_blocks_metrics_table
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        [
          'Authentic Drivers License',
          total_doc_auth_fail.to_s,
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
          total_selfie_fail.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Identity Not Found',
          identity_not_found_failed_count.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Address / Occupancy Match',
          address_occupancy_failed_count.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Social Security Number Match',
          ssn_failed_count.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Date of Birth Match',
          dob_failed_count.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Deceased Check',
          dead_failed_count.to_s,
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
        # ---------------------------------------------------------------------------------
      ]
    end

    # table Key Points of User Friction ---------------------------------------------------
    def key_points_user_friction_metrics_table
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        [
          'Document selfie upload UX challenge',
          doc_selfie_ux_challenge_socure_and_lexis.to_s,
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
        # -------------------------------------------------------------------------------
      ]
    end

    # table for successful ipp
    def successful_ipp_table
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

    # Create Data Dictionary that will store results from each cloudwatch query ------------
    def data_authentic_license_facial_match_socure
      @data_authentic_license_facial_match_socure ||= begin
        event_users = Hash.new { |h, event| h[event] = Set.new }
        fetch_authentic_drivers_license_facial_match_socure_results.each do |row|
          event_users[Events::DOC_AUTH_FACIAL_SOCURE] << row['document_fail_count_socure']
          event_users[Events::SELFIE_FAIL_SOCURE] << row['selfie_fail_count_socure']
        end
        event_users
      end
    end

    def data_authentic_license_facial_match_lexis
      @data_authentic_license_facial_match_lexis ||= begin
        event_users = Hash.new { |h, event| h[event] = Set.new }
        fetch_authentic_drivers_license_facial_match_lexis_results.each do |row|
          event_users[Events::DOC_AUTH_FACIAL_LEXIS] << row['document_fail_count_lexis']
          event_users[Events::SELFIE_FAIL_LEXIS] << row['selfie_fail_count_lexis']
        end
        event_users
      end
    end

    def data_valid_drivers_license_number
      @data_valid_drivers_license_number ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_valid_drivers_license_number_results.each do |row|
          event_users[Events::VAILD_DRIVERS_LICENSE_NUMBER] << row['aamva_failed_count']
        end

        event_users
      end
    end

    def data_fetch_address_dob_dead_ssn_identity_notfound_results
      @data_fetch_address_dob_dead_ssn_identity_notfound_results ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_address_dob_dead_ssn_identity_notfound_results.each do |row|
          event_users[Events::ADDRESS_OCCUPANCY] << row['address_failed_count']
          event_users[Events::DOB] << row['dob_failed_count']
          event_users[Events::DEAD] << row['death_failed_count']
          event_users[Events::SSN] << row['ssn_failed_count']
          event_users[Events::IDENTITY_NOT_FOUND] << row['identity_not_found_count']
        end

        event_users
      end
    end

    def data_fetch_phone_account_ownership_results
      @data_fetch_phone_account_ownership_results ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_phone_account_ownership_results.each do |row|
          event_users[Events::PHONE_ACCOUNT_OWNERSHIP] << row['phone_finder_fail_count']
        end

        event_users
      end
    end

    def data_fetch_device_behavior_fraud_signals_results
      @data_fetch_device_behavior_fraud_signals_results ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_device_behavior_fraud_signals_results.each do |row|
          event_users[Events::DEVICE_BEHAVIOR_FRAUD_SIGNALS] << row['DeviceBehavoirFraudSig']
        end
        event_users
      end
    end

    def data_fetch_doc_selfie_ux_challenge_socure_results
      @data_fetch_doc_selfie_ux_challenge_socure_results ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_doc_selfie_ux_challenge_socure_results.each do |row|
          event_users[Events::DOC_SELFIE_UX_CHALLENGE_SOCURE] << row['sum_capture_quality_fail']
        end
        event_users
      end
    end

    def data_fetch_doc_selfie_ux_challenge_lexis_results
      @data_fetch_doc_selfie_ux_challenge_lexis_results ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_doc_selfie_ux_challenge_lexis_results.each do |row|
          event_users[Events::DOC_SELFIE_UX_CHALLENGE_LEXIS] << row['sum_any_capture']
        end
        event_users
      end
    end

    def data_fetch_verif_code_not_received_results
      @data_fetch_verif_code_not_received_results ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_verification_code_not_received_results.each do |row|
          event_users[Events::VERF_CODE_NOT_RECIEVED] << row['sum_verification_code_not_received']
        end
        event_users
      end
    end

    def data_fetch_api_connection_fails_results
      @data_fetch_api_connection_fails_results ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_api_connection_fails_results.each do |row|
          event_users[Events::API_CONNECTION_FAILS] << row['api_user_fail']
          # event_users[row['api_user_fail']] << row['api_user_fail']
          # event_users[row['AAMVA_fail_count']] << row['AAMVA_fail_count']
          # event_users[row['LN_timeout_fail_count']] << row['LN_timeout_fail_count']
          # event_users[row['state_timeout_fail_count']] << row['state_timeout_fail_count']
        end
        event_users
      end
    end

    def data_fetch_successful_ipp_results
      @data_fetch_successful_ipp_results ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_successful_ipp_results.each do |row|
          event_users[Events::SUCCESSFUL_IPP_OUTPUT] << row['IPP_successfully_proofed_user_counts']
        end
        event_users
      end
    end

    # ipp_barcode_count
    def data_fetch_ipp_barcode_results
      @data_fetch_ipp_barcode_results ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_ipp_barcode_results.each do |row|
          event_users[Events::IPP_BARCODE_OUTPUT] << row['ipp_barcode_count']
        end
        event_users
      end
    end

    # TODO: END --------------------------------------------------------------------------

    # TODO: SQL QUERY FOR IDP---------------------------------------------------------------
    # fetch command for idp sql query ------------------------------------------------------
    def fetch_proofing_ial2_data
      params = {
        start_date: time_range.begin,
        end_date: time_range.end + 1,
        issuer: issuers.first,
      }.transform_values { |v| ActiveRecord::Base.connection.quote(v) }

      sql = format(<<-SQL, params)
      WITH
      base_data AS (
            SELECT 
                user_id,
                ial
            FROM sp_return_logs
      
            WHERE 
                billable = TRUE
                AND issuer = %{issuer}
                AND returned_at >= CAST(%{start_date} AS DATE)
                AND returned_at < CAST(%{end_date} AS DATE)
          )
      SELECT
          COUNT(DISTINCT CASE WHEN ial = 2 THEN user_id END) AS ial_2
      FROM base_data;
      SQL

      ial2_result = Reports::BaseReport.transaction_with_timeout do
        ActiveRecord::Base.connection.execute(sql)
      end

      return ial2_result.to_a[0].values[0]
    end
    # TODO: END --------------------------------------------------------------------------

    # fetch commands for cloudwatch queries ------------------------------------------------
    def fetch_authentic_drivers_license_facial_match_socure_results
      cloudwatch_client.fetch(
        query: authentic_drivers_license_facial_match_socure_query, from: time_range.begin,
        to: time_range.end
      )
    end

    def fetch_authentic_drivers_license_facial_match_lexis_results
      cloudwatch_client.fetch(
        query: authentic_drivers_license_facial_match_lexis_query, from: time_range.begin,
        to: time_range.end
      )
    end

    def fetch_valid_drivers_license_number_results
      cloudwatch_client.fetch(
        query: valid_drivers_license_number_query, from: time_range.begin,
        to: time_range.end
      )
    end

    def fetch_address_dob_dead_ssn_identity_notfound_results
      cloudwatch_client.fetch(
        query: address_dob_dead_ssn_identity_notfound_query, from: time_range.begin,
        to: time_range.end
      )
    end

    def fetch_phone_account_ownership_results
      cloudwatch_client.fetch(
        query: phone_account_ownership_query, from: time_range.begin,
        to: time_range.end
      )
    end

    def fetch_device_behavior_fraud_signals_results
      cloudwatch_client.fetch(
        query: device_behavior_fraud_signals_query, from: time_range.begin,
        to: time_range.end
      )
    end

    def fetch_doc_selfie_ux_challenge_socure_results
      cloudwatch_client.fetch(
        query: doc_selfie_ux_challenge_socure_query, from: time_range.begin,
        to: time_range.end
      )
    end

    def fetch_doc_selfie_ux_challenge_lexis_results
      cloudwatch_client.fetch(
        query: doc_selfie_ux_challenge_lexis_query, from: time_range.begin,
        to: time_range.end
      )
    end

    def fetch_verification_code_not_received_results
      cloudwatch_client.fetch(
        query: verification_code_not_received_query, from: time_range.begin,
        to: time_range.end
      )
    end

    def fetch_api_connection_fails_results
      cloudwatch_client.fetch(
        query: api_connection_fails_query, from: time_range.begin, to: time_range.end,
      )
    end

    def fetch_successful_ipp_results
      cloudwatch_client.fetch(
        query: successful_ipp_query, from: time_range.begin,
        to: time_range.end
      )
    end

    def fetch_ipp_barcode_results
      cloudwatch_client.fetch(
        query: ipp_barcode_query, from: time_range.begin,
        to: time_range.end
      )
    end

    # ---------------------------------------------------------------------------------------
    def as_tables
      [
        overview_table,
        # proofing_success_metrics_table,
        suspected_fraud_blocks_metrics_table,
        key_points_user_friction_metrics_table,
        successful_ipp_table,
      ]
    end

    def to_csvs
      as_tables.map do |table|
        CSV.generate do |csv|
          table.each do |row|
            csv << row
          end
        end
      end
    end

    # ---------------------------------------------------------------------------------------
    def authentic_drivers_license_facial_match_socure_query
      params = {
        issuers: quote(issuers),
        idv_socure_verification_data_requested: quote(
          Events::IDV_SOCURE_VERIFICATION_DATA_REQUESTED,
        ),
        doc_auth_facial_socure: quote(Events::DOC_AUTH_FACIAL_SOCURE),
        selfie_fail_socure: quote(Events::SELFIE_FAIL_SOCURE),
      }
      format(<<~QUERY, params)
        filter name = %{idv_socure_verification_data_requested}
        | filter properties.service_provider in %{issuers}
        | parse @message '"reason_codes":[*]' as @reason_codes
        | fields properties.event_properties.success as @document_authentication_success,
                !properties.event_properties.doc_auth_success as @document_fail,
                @reason_codes like 'R836' as @selfie_fail
        | stats max(@document_authentication_success) as document_authentication_success,
                max(@document_fail) as document_fail,
                max(@selfie_fail) as selfie_fail
                by properties.user_id
        | filter !document_authentication_success
        | stats sum(document_fail) as document_fail_count_socure,
                sum(selfie_fail) as selfie_fail_count_socure
        | limit 10000
      QUERY
    end

    def authentic_drivers_license_facial_match_lexis_query
      params = {
        issuers: quote(issuers),
        idv_doc_auth_image_upload_vendor_submitted: quote(
          Events::IDV_DOC_AUTH_IMAGE_UPLOAD_VENDOR_SUBMITTED,
        ),
        doc_auth_facial_lexis: quote(Events::DOC_AUTH_FACIAL_LEXIS),
        selfie_fail_lexis: quote(Events::SELFIE_FAIL_LEXIS),
      }
      format(<<~QUERY, params)
        filter name = %{idv_doc_auth_image_upload_vendor_submitted}
        | filter properties.service_provider in %{issuers}
        | fields properties.event_properties.success as @document_authentication_success,
                !properties.event_properties.doc_auth_success as @document_fail,
                properties.event_properties.selfie_status = 'fail' as @selfie_fail
        | stats max(@document_authentication_success) as document_authentication_success,
                max(@document_fail) as document_fail,
                max(@selfie_fail) as selfie_fail
                by properties.user_id
        | filter !document_authentication_success
        | stats sum(document_fail) as document_fail_count_lexis,
                sum(selfie_fail) as selfie_fail_count_lexis
        | limit 10000

      QUERY
    end

    def valid_drivers_license_number_query
      params = {
        issuers: quote(issuers),
        idv_doc_auth_verify_proofing_results: quote(Events::IDV_DOC_AUTH_VERIFY_PROOFING_RESULTS),
        valid_drivers_license_number: quote(Events::VAILD_DRIVERS_LICENSE_NUMBER),
      }
      format(<<~QUERY, params)
        filter name = %{idv_doc_auth_verify_proofing_results}
        | filter properties.service_provider in %{issuers}
        | fields jsonParse(@message) as message
        | unnest message.properties.event_properties.proofing_results.context.stages.state_id into state_id
        | fields state_id.success as @aamva_passed

        | fields properties.event_properties.success as @verify_info_success
        | filter ispresent(@verify_info_success) and ispresent(@aamva_passed)
        | stats max(@verify_info_success) as verify_info_success,
                max(!@aamva_passed) as aamva_failed
                by properties.user_id
        | filter !verify_info_success
        | stats sum(aamva_failed) as aamva_failed_count
        | limit 10000

      QUERY
    end

    def address_dob_dead_ssn_identity_notfound_query
      params = {
        issuers: quote(issuers),
        idv_doc_auth_verify_proofing_results: quote(Events::IDV_DOC_AUTH_VERIFY_PROOFING_RESULTS),
      }
      format(<<~QUERY, params)
        filter name = %{idv_doc_auth_verify_proofing_results}
        | filter properties.service_provider in %{issuers}
        | fields properties.event_properties.success as @verify_info_success
        | fields jsonParse(@message) as message

        | unnest message.properties.event_properties.proofing_results into proofing_results
        | unnest proofing_results.context into context
        | unnest context.stages into stages
        | unnest stages.residential_address into residential_address
        | unnest residential_address.success into residential_address_success
        | unnest stages.resolution into resolution
        | unnest resolution.success into resolution_success
        | unnest residential_address.attributes_requiring_additional_verification into residential_address_need_addtl_verify
        | unnest resolution.attributes_requiring_additional_verification into resolution_need_addtl_verify

        | fields coalesce(residential_address_need_addtl_verify, 'none') as resudential_address_need_addtl_verify_fill_na
        | fields coalesce(resolution_need_addtl_verify, 'none') as resolution_need_addtl_verify_fill_na

        | fields if(resudential_address_need_addtl_verify_fill_na like 'address' or resolution_need_addtl_verify_fill_na like 'address', 1, 0) as address
        | fields if(resudential_address_need_addtl_verify_fill_na like 'dob' or resolution_need_addtl_verify_fill_na like 'dob', 1, 0) as dob
        | fields if(resudential_address_need_addtl_verify_fill_na like 'ssn' or resolution_need_addtl_verify_fill_na like 'ssn', 1, 0) as ssn
        | fields if(resudential_address_need_addtl_verify_fill_na like 'dead' or resolution_need_addtl_verify_fill_na like 'dead', 1, 0) as dead

        | fields if(residential_address_success=1 and resolution_success=1, 1, 0) as @iv_passed

        | stats max(@verify_info_success) as verify_info_success,
                max(@iv_passed) as iv_passed,
                max(address) as address_failed,
                max(dob) as dob_failed,
                max(dead) as death_failed,
                max(ssn) as ssn_failed
                by properties.user_id

        | filter !verify_info_success
        | stats sum(address_failed) as address_failed_count,
                sum(dob_failed) as dob_failed_count,
                sum(death_failed) as death_failed_count,
                sum(ssn_failed) as ssn_failed_count,
                sum(iv_passed=0 and address_failed=0 and dob_failed=0 and death_failed=0 and ssn_failed=0) as identity_not_found_count
        | limit 10000
      QUERY
    end

    def phone_account_ownership_query
      params = {
        issuers: issuers,
        idv_phone_conf_vendor: quote(Events::IDV_PHONE_CONF_VENDOR),
        phone_account_ownership: quote(Events::PHONE_ACCOUNT_OWNERSHIP),
      }
      format(<<~QUERY, params)
        filter name = %{idv_phone_conf_vendor}
        | filter properties.service_provider in %{issuers}
        | fields properties.event_properties.success as @phone_finder_success
        | stats max(@phone_finder_success) as phone_finder_success by properties.user_id
        | stats sum(!phone_finder_success) as phone_finder_fail_count 
        | limit 10000

      QUERY
    end

    def device_behavior_fraud_signals_query
      params = {
        issuers: quote(issuers),
        idv_doc_auth_verify_proofing_results: quote(Events::IDV_DOC_AUTH_VERIFY_PROOFING_RESULTS),
        device_behavior_fraud_signals: quote(Events::DEVICE_BEHAVIOR_FRAUD_SIGNALS),
      }
      format(<<~QUERY, params)
        fields name, @timestamp, 
          properties.event_properties.proofing_results.threatmetrix_review_status as tmx_result, 
          properties.user_id as user_id, properties.new_event as new_event
          | filter name = %{idv_doc_auth_verify_proofing_results}
          | filter tmx_result = 'reject'
          | filter properties.service_provider in %{issuers}
          | filter new_event=1
          | stats
              max(new_event) as user_count_new_event by properties.user_id
          | stats
              sum(user_count_new_event) as DeviceBehavoirFraudSig
          | limit 10000

      QUERY
    end

    def doc_selfie_ux_challenge_socure_query
      params = {
        issuers: quote(issuers),
        idv_socure_verification_data_requested: quote(
          Events::IDV_SOCURE_VERIFICATION_DATA_REQUESTED,
        ),
        idv_doc_auth_ssn_visited: quote(Events::IDV_DOC_AUTH_SSN_VISITED),
        doc_selfie_ux_challenges_socure: quote(Events::DOC_SELFIE_UX_CHALLENGE_SOCURE),
      }
      format(<<~QUERY, params)
        filter (name = %{idv_socure_verification_data_requested}) or (name = %{idv_doc_auth_ssn_visited})
        | filter properties.service_provider in %{issuers}
        | parse @message '"reason_codes":[*]' as @reason_codes
        | fields 
            (name = %{idv_socure_verification_data_requested}) as @the_socure_event,
            (name = %{idv_doc_auth_ssn_visited}) as @ssn_visited,
            (@the_socure_event and (@reason_codes like 'R836')) as @selfie_match_fail,
            (@the_socure_event and (@reason_codes like 'R834')) as @liveness_fail,
            (@the_socure_event and ((@reason_codes like 'R850') or (@reason_codes like 'R857') or (@reason_codes like 'R856'))) as @selfie_quality_fail,
            (@the_socure_event and (@reason_codes like 'R804')) as @color_req,
            (@the_socure_event and (@reason_codes like 'R845')) as @minimum_age_error,
            ((@the_socure_event and (@reason_codes like 'R838'))) as @front_illegible,    
            (@the_socure_event and (((@reason_codes like 'R831') or (@reason_codes like 'R833')))) as @barcode_illegible
        | stats 
            max(@ssn_visited) as ssn_visited,
            max(@selfie_quality_fail) as selfie_quality_fail,
            max(@color_req) as color_fail,
            max(@selfie_match_fail) as selfie_match_fail,
            max(@liveness_fail) as liveness_fail,
            max(@front_illegible) as front_illegible_fail,
            max(@barcode_illegible) as barcode_illegible_fail    
            by properties.user_id
        | filter (ssn_visited=0) 
        | fields 
            barcode_illegible_fail=1 or color_fail=1 or front_illegible_fail=1 as doc_quality_fail,
            selfie_quality_fail=1 or doc_quality_fail=1 as capture_quality_fail
        | stats 
            # sum(doc_quality_fail) as sum_doc_quality_fail,
            # sum(selfie_quality_fail) as sum_selfie_quality_fail,
            sum(capture_quality_fail) as sum_capture_quality_fail
        | limit 10000
      QUERY
    end

    def doc_selfie_ux_challenge_lexis_query
      params = {
        issuers: quote(issuers),
        idv_front_image_added: quote(Events::IDV_FRONT_IMAGE_ADDED),
        idv_back_image_added: quote(Events::IDV_BACK_IMAGE_ADDED),
        idv_doc_auth_image_upload_vendor_submitted: quote(
          Events::IDV_DOC_AUTH_IMAGE_UPLOAD_VENDOR_SUBMITTED,
        ),
        idv_doc_auth_ssn_visited: quote(Events::IDV_DOC_AUTH_SSN_VISITED),
        doc_selfie_ux_challenge_lexis: quote(Events::DOC_SELFIE_UX_CHALLENGE_LEXIS),
      }
      # might need to adjust the name in to be name =  for each and remove the brackets
      format(<<~QUERY, params)
        filter properties.service_provider in %{issuers}
        | filter (name = %{idv_front_image_added}) or (name = %{idv_back_image_added}) or (name = %{idv_doc_auth_image_upload_vendor_submitted}) or (name = %{idv_doc_auth_ssn_visited})
        | fields 
            properties.user_id,
            properties.event_properties.isAssessedAsBlurry as isAssessedAsBlurry,
            properties.event_properties.isAssessedAsGlare as isAssessedAsGlare,
            properties.event_properties.isAssessedAsUnsupported as isAssessedAsUnsupported
        | fields 
            ((name = %{idv_front_image_added} or name = %{idv_back_image_added}) and isAssessedAsBlurry) as blur_error_1,
            coalesce(blur_error_1,0) as blur_error,
            ((name =%{idv_front_image_added} or  name=%{idv_back_image_added}) and isAssessedAsGlare) as glare_error_1,
            coalesce(glare_error_1,0) as glare_error,
            # (name in [%{idv_front_image_added}, %{idv_back_image_added}] and isAssessedAsUnsupported) as doctype_error,   
            (name = %{idv_doc_auth_image_upload_vendor_submitted} and !properties.event_properties.selfie_quality_good) as selfie_fail_1,
            coalesce(selfie_fail_1,0) as selfie_fail,
            (name = %{idv_doc_auth_ssn_visited}) as ssn_visited
        | stats 
            max(blur_error) as @blur_error,
            max(glare_error) as @glare_error,
            max(selfie_fail) as @selfie_fail,
            max(ssn_visited) as @ssn_visited
            by properties.user_id
        | filter (@ssn_visited=0)
        | fields 
            @blur_error=1 or @glare_error=1 as @doc_fail,
            (@doc_fail=1 or @selfie_fail=1) as @any_capture_error
        | filter (@any_capture_error=1)
        | stats 
            sum(@any_capture_error) as sum_any_capture
            # sum(@selfie_fail) as sum_selfie_fail,
            # sum(@doc_fail) as sum_doc_fail
        | limit 10000
      QUERY
    end

    def verification_code_not_received_query
      params = {
        issuers: quote(issuers),
        idv_phone_conf_otp_visited: quote(Events::IDV_PHONE_CONF_OTP_VISITED),
        idv_phone_conf_otp_submitted: quote(Events::IDV_PHONE_CONF_OTP_SUBMITTED),
        idv_enter_password_visited: quote(Events::IDV_ENTER_PASSWORD_VISITED),
        verification_code_not_received: quote(Events::VERF_CODE_NOT_RECIEVED),
      }
      format(<<~QUERY, params)
        # Verification code not received
        filter (name = %{idv_phone_conf_otp_visited}) or (name= %{idv_phone_conf_otp_submitted}) or (name = %{idv_enter_password_visited})
        | filter properties.service_provider in %{issuers}
        | fields (name = %{idv_phone_conf_otp_visited}) as @code_sent,
            (name = %{idv_phone_conf_otp_submitted}) as @code_submitted,
            (name = %{idv_enter_password_visited}) as @code_successfully_submitted
        | stats max(@code_sent) as code_sent,
                max(@code_submitted) as code_submitted,
                max(@code_successfully_submitted) as code_successfully_submitted
                by properties.user_id
        | filter code_successfully_submitted=0
        | fields code_sent and code_submitted=0 as code_error 
        | stats sum(code_error) as sum_verification_code_not_received
        | limit 10000
      QUERY
    end

    # --------------------------------------------------------------------------
    def api_connection_fails_query
      params = {
        issuers: quote(issuers),
        idv_doc_auth_verify_proofing_results: quote(Events::IDV_DOC_AUTH_VERIFY_PROOFING_RESULTS),
        idv_phone_record_visited: quote(Events::IDV_PHONE_RECORD_VISITED),
        api_connection_fails: quote(Events::API_CONNECTION_FAILS),
      }
      # might need to adjust the name in to be name =  for each and remove the brackets
      format(<<~QUERY, params)
        filter (name = %{idv_doc_auth_verify_proofing_results}) or (name= %{idv_phone_record_visited})
        | filter properties.service_provider in %{issuers}
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
            # sum(aamva_fail) as AAMVA_fail_count,
            # sum(ln_fail) as LN_timeout_fail_count,
            # sum(state_timeout_fail) as state_timeout_fail_count,
            count(*) as api_user_fail  
        | limit 10000  
      QUERY
    end

    def successful_ipp_query
      params = {
        issuers: quote(issuers),
        successful_ipp: quote(Events::SUCCESSFUL_IPP),
        successful_ipp_output: quote(Events::SUCCESSFUL_IPP_OUTPUT),
      }

      format(<<~QUERY, params)
        filter name = %{successful_ipp}
        | fields 
            (name = %{successful_ipp} and 
            properties.event_properties.passed=1 
            and properties.event_properties.issuer in %{issuers}) as @ipp_verified
        | filter @ipp_verified=1

        |stats
            sum(@ipp_verified) as IPP_successfully_proofed_user_counts
        | limit 10000
      QUERY
    end

    def ipp_barcode_query
      params = {
        issuers: quote(issuers),
        troubleshooting_option: quote(Events::TROUBLESHOOTING_OPTION),
        ipp_ready_to_verify: quote(Events::IPP_READY),
        ipp_barcode_output: quote(Events::IPP_BARCODE_OUTPUT),

      }

      format(<<~QUERY, params)
        filter (name = %{troubleshooting_option}) or  
            (name = %{ipp_barcode_output})
        | filter properties.service_provider in %{issuers} or properties.event_properties.issuer in %{issuers}
        | fields 
            (name = %{troubleshooting_option}) as @ipp_clicked_troubleshooting,
            (name = %{ipp_barcode_output}) as @ipp_barcode
        | stats 
            max(@ipp_clicked_troubleshooting) as ipp_clicked_troubleshooting,
            max(@ipp_barcode) as ipp_barcode

            by properties.user_id
        | filter (ipp_clicked_troubleshooting=1)
        | stats
            sum(ipp_barcode) as ipp_barcode_count
        | limit 10000
      QUERY
    end

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        num_threads: @threads,
        ensure_complete_logs: true,
        slice_interval: @slice,
        progress: progress?,
        logger: verbose? ? Logger.new(STDERR) : nil,
      )
    end

    # Extracting data that was gathered from idp sql query and placed in dictionaries -------------
    def ial2
      @ial2 = fetch_proofing_ial2_data
    end
    # ---------------------------------------------------------------------------------------------

    def sum_key_friction_points
      @sum_key_friction_points = doc_selfie_ux_challenge_socure_and_lexis +
                                 verification_code_not_received_count + api_connection_fails
    end

    def denominator
      # to do need to calculate ipp_barcode and then subtract it from the following line
      @denominator = (ial2 + sum_key_friction_points) - ipp_barcode_count
    end

    def idv_rate
      # @idv_rate = '86.34%' # just testing
      @idv_rate || (ial2 / denominator.to_f * 100).round(2).to_s + '%'
    end

    def ipp_barcode_count
      set = @ipp_barcode_count || data_fetch_ipp_barcode_results[Events::IPP_BARCODE_OUTPUT]
      set || Set[]
      set.find { |v| v }&.to_i || 0
    end

    # ---------------------------------------------------------------------------------------------

    # Extracting data that was gathered from queries and placed in dictionaries -------------
    def authentic_drivers_license_facial_check_lexis
      @authentic_drivers_license_facial_check_lexis || data_authentic_license_facial_match_lexis[
        Events::DOC_AUTH_FACIAL_LEXIS]
    end

    def authentic_drivers_license_facial_check_socure
      @authentic_drivers_license_facial_check_socure || data_authentic_license_facial_match_socure[
        Events::DOC_AUTH_FACIAL_SOCURE]
    end

    def selfie_fail_lexis
      @selfie_fail_lexis || data_authentic_license_facial_match_lexis[
        Events::SELFIE_FAIL_LEXIS]
    end

    def selfie_fail_socure
      @selfie_fail_socure || data_authentic_license_facial_match_socure[
        Events::SELFIE_FAIL_SOCURE]
    end

    def total_doc_auth_fail
      lexis_set = authentic_drivers_license_facial_check_lexis || Set[]
      socure_set = authentic_drivers_license_facial_check_socure || Set[]

      lexis_value = lexis_set.find { |v| v }&.to_i || 0
      socure_value = socure_set.find { |v| v }&.to_i || 0

      @total_doc_auth_fail ||= lexis_value + socure_value
    end

    def total_selfie_fail
      lexis_set = selfie_fail_lexis || Set[]
      socure_set = selfie_fail_socure || Set[]

      lexis_value = lexis_set.find { |v| v }&.to_i || 0
      socure_value = socure_set.find { |v| v }&.to_i || 0
      @total_selfie_fail ||= lexis_value + socure_value
    end

    def valid_drivers_license_number
      set = @valid_drivers_license_number || data_valid_drivers_license_number[
        Events::VAILD_DRIVERS_LICENSE_NUMBER]
      set ||= Set[] # Ensure it's never nil
      # Find the first non-nil value, convert to integer, or default to 0
      set.find { |v| v }&.to_i || 0
    end

    def address_occupancy_failed_count
      set = data_fetch_address_dob_dead_ssn_identity_notfound_results[Events::ADDRESS_OCCUPANCY]
      set || Set[]
      set.find { |v| v }&.to_i || 0
    end

    def dob_failed_count
      set = data_fetch_address_dob_dead_ssn_identity_notfound_results[Events::DOB] || Set[]
      set.find { |v| v }&.to_i || 0
    end

    def dead_failed_count
      set = data_fetch_address_dob_dead_ssn_identity_notfound_results[Events::DEAD] || Set[]
      set.find { |v| v }&.to_i || 0
    end

    def ssn_failed_count
      set = data_fetch_address_dob_dead_ssn_identity_notfound_results[Events::SSN] || Set[]
      set.find { |v| v }&.to_i || 0
    end

    def identity_not_found_failed_count
      set = data_fetch_address_dob_dead_ssn_identity_notfound_results[Events::IDENTITY_NOT_FOUND]
      set || Set[]
      set.find { |v| v }&.to_i || 0
    end

    def phone_account_ownership
      set = @phone_account_ownership || data_fetch_phone_account_ownership_results[
        Events::PHONE_ACCOUNT_OWNERSHIP]
      set ||= Set[]
      set.find { |v| v }&.to_i || 0
    end

    def device_behavior_fraud_signals
      set = @device_behavior_fraud_signals || data_fetch_device_behavior_fraud_signals_results[
        Events::DEVICE_BEHAVIOR_FRAUD_SIGNALS]
      set ||= Set[]
      set.find { |v| v }&.to_i || 0
    end

    def doc_selfie_ux_challenge_lexis
      @doc_selfie_ux_challenge_lexis || data_fetch_doc_selfie_ux_challenge_lexis_results[
        Events::DOC_SELFIE_UX_CHALLENGE_LEXIS]
    end

    def doc_selfie_ux_challenges_socure
      @doc_selfie_ux_challenge_socure || data_fetch_doc_selfie_ux_challenge_socure_results[
        Events::DOC_SELFIE_UX_CHALLENGE_SOCURE]
    end

    def doc_selfie_ux_challenge_socure_and_lexis
      lexis_set = doc_selfie_ux_challenge_lexis || Set[]
      socure_set = doc_selfie_ux_challenges_socure || Set[]

      lexis_value = lexis_set.find { |v| v }&.to_i || 0
      socure_value = socure_set.find { |v| v }&.to_i || 0

      @doc_selfie_ux_challenge_socure_and_lexis ||= lexis_value + socure_value
    end

    def verification_code_not_received_count
      set = @verification_code_not_received_count || data_fetch_verif_code_not_received_results[
        Events::VERF_CODE_NOT_RECIEVED]
      set ||= Set[] # Ensure it's never nil
      # Find the first non-nil value, convert to integer, or default to 0
      set.find { |v| v }&.to_i || 0
    end

    def api_connection_fails
      set = @api_connection_fails || data_fetch_api_connection_fails_results[
        Events::API_CONNECTION_FAILS]
      set ||= Set[]
      set.find { |v| v }&.to_i || 0 # finds first non-nil value, e.g. "4"
    end

    # successful ipp users
    def successful_ipp_users_count
      set = @successful_ipp_users_count || data_fetch_successful_ipp_results[
        Events::SUCCESSFUL_IPP_OUTPUT]
      set ||= Set[]
      set.find { |v| v }&.to_i || 0
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  options = Reporting::CommandLineOptions.new.parse!(ARGV, require_issuer: false)

  Reporting::TestIdentityVerificationOutcomesReport.new(**options).to_csvs.each do |csv|
    puts csv
  end
end
