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
  class ApiTransactionCountReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :time_range

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

    def as_tables
      [
        api_transaction_count,
      ]
    end

    def as_emailable_reports
      [
        Reporting::EmailableReport.new(
          subtitle: '',
          float_as_percent: true,
          precision: 2,
          table: api_transaction_count,
          filename: 'api_transaction_count_report',
        ),
      ]
    end

    def to_csvs
      as_emailable_reports.map do |report|
        CSV.generate do |csv|
          report.table.each { |row| csv << row }
        end
      end
    end

    def api_transaction_count
      [
        [
          'Week',
          'True ID',
          'Instant verify',
          'Phone Finder',
          'Socure (DocV)',
          'Socure (KYC) - Shadow',
          'Socure (KYC) - Non-Shadow',
          'Fraud Score and Attribute',
          'Threat Metrix',
        ],
        [
          "#{ time_range.begin.to_date} - #{time_range.end.to_date}",
          true_id_table.first,
          instant_verify_table.first,
          phone_finder_table.first,
          socure_table.first,
          socure_kyc_non_shadow_table.first,
          socure_kyc_shadow_table.first,
          fraud_score_and_attribute_table.first,
          threat_metrix_table.first,
        ],
      ]
    end

    private

    def previous_week_range
      today = Time.zone.today
      last_sunday = today.beginning_of_week(:sunday) - 7.days
      last_saturday = last_sunday + 6.days

      last_sunday.to_date..last_saturday.to_date
    end

    def true_id_table
      result = fetch_results(query: true_id_query)
      true_id_table_count = result.count
      [true_id_table_count, result]
    end

    def phone_finder_table
      result = fetch_results(query: phone_finder_query)
      phone_finder_table_count = result.count
      [phone_finder_table_count, result]
    end

    def socure_table
      result = fetch_results(query: socure_query)
      socure_table_count = result.count
      [socure_table_count, result]
    end

    def socure_kyc_non_shadow_table
      result = fetch_results(query: socure_kyc_non_shadow_query)
      socure_table_count = result.count
      [socure_table_count, result]
    end

    def socure_kyc_shadow_table
      result = fetch_results(query: socure_kyc_shadow_query)
      socure_table_count = result.count
      [socure_table_count, result]
    end

    def instant_verify_table
      result = fetch_results(query: instant_verify_query)
      instant_verify_table_count = result.count
      [instant_verify_table_count, result]
    end

    def threat_metrix_table
      result = fetch_results(query: threat_metrix_query)
      threat_metrix_table_count = result.count
      [threat_metrix_table_count, result]
    end

    def fraud_score_and_attribute_table
      result = fetch_results(query: fraud_score_and_attribute_query)
      fraud_score_and_attribute_table_count = result.count
      [fraud_score_and_attribute_table_count, result]
    end

    def fetch_results(query:)
      Rails.logger.info("Executing query: #{query}")
      Rails.logger.info("Time range: #{time_range.begin.to_time} to #{time_range.end.to_time}")

      results = cloudwatch_client.fetch(
        query:,
        from: time_range.begin.to_time,
        to: time_range.end.to_time,
      )

      Rails.logger.info("Results: #{results.inspect}")
      results
    rescue StandardError => e
      Rails.logger.error("Failed to fetch results for query: #{e.message}")
      []
    end

    def column_labels(row)
      row&.keys || []
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

    def true_id_query
      <<~QUERY
        #TrueID
        filter name = "IdV: doc auth image upload vendor submitted"
        | fields properties.user_id as uuid, id, @timestamp as timestamp,
        properties.sp_request.app_differentiator as dol_state, properties.event_properties.success as success,
        properties.service_provider as sp,
        properties.event_properties.billed as billed,
        properties.event_properties.conversation_id as conversation_id,
        properties.event_properties.decision_product_status as decision_status,
        properties.event_properties.product_status as product_status,
        properties.event_properties.reference as referenceID,
        properties.event_properties.remaining_submit_attempts as remaining_submit_attempts,
        properties.event_properties.request_id as request_id,
        properties.event_properties.submit_attempts as submit_attempts,
        properties.event_properties.transaction_status as transaction_status,
        properties.event_properties.vendor as vendor
        | display uuid, id, timestamp, sp, dol_state, success,
        billed, vendor, product_status, transaction_status, conversation_id, request_id, referenceID, decision_status, submit_attempts, remaining_submit_attempts
      QUERY
    end

    def phone_finder_query
      <<~QUERY
        #PhoneFinder
        filter name = "IdV: phone confirmation vendor"
        | fields properties.user_id as uuid, id, @timestamp as timestamp,
        properties.sp_request.app_differentiator as dol_state,
        properties.service_provider as sp,
        properties.event_properties.vendor.transaction_id as phoneFinder_transactionID,
        properties.event_properties.vendor.reference as phoneFinder_referenceID,
        strcontains(properties.event_properties.errors.base.0,"pass") as phoneFinder_pass,
        properties.event_properties.success as success,
        properties.event_properties.area_code as area_code,
        properties.event_properties.country_code as country_code,
        properties.event_properties.phone_fingerprint as phone_fingerprint
        | parse @message /"Items":\[(?<temp_checks>.*?)\]/
        | display uuid, id, timestamp, sp, dol_state, success,
          phoneFinder_referenceID, phoneFinder_transactionID, phoneFinder_pass,
          coalesce(temp_checks,"passed_all","") as phoneFinder_checks
      QUERY
    end

    def socure_query
      <<~QUERY
        #socure
        filter name = "idv_socure_verification_data_requested"
        | fields properties.user_id as uuid, id, @timestamp as timestamp,
        properties.sp_request.app_differentiator as dol_state, properties.event_properties.success as success,
        properties.service_provider as sp,
        properties.event_properties.decision.value as decision_result,
        properties.event_properties.docv_transaction_token as docv_transaction_token,
        properties.event_properties.reference_id as reference_id, properties.event_properties.submit_attempts as submit_attempts,
        replace(replace(strcontains(name, "front"),"1","front"),"0","back") as side
        | display uuid, id, timestamp, sp, dol_state, success, decision_result, side, docv_transaction_token, reference_id, submit_attempts
      QUERY
    end

    def instant_verify_query
      <<~QUERY
          #LN Stack
        filter name = "IdV: doc auth verify proofing results"
        | fields properties.user_id as uuid, id, @timestamp as timestamp,
        properties.sp_request.app_differentiator as dol_state, properties.service_provider as sp,

        #OVERALL
        properties.event_properties.proofing_results.timed_out as overall_process_timed_out_flag,
        properties.event_properties.success as overall_process_success,
        properties.event_properties.proofing_components.document_check as document_check_vendor,
        properties.event_properties.proofing_results.context.stages.residential_address.vendor_name as address_vendor_name,

        #instantVerify --> resolution
        properties.event_properties.proofing_results.context.stages.resolution.reference as resolution_referenceID,
        properties.event_properties.proofing_results.context.stages.resolution.success as resolution_success,
        properties.event_properties.proofing_results.context.stages.resolution.timed_out as resolution_timed_out_flag,
        properties.event_properties.proofing_results.context.stages.resolution.transaction_id as resolution_transactionID,
        properties.event_properties.proofing_results.context.stages.resolution.vendor_name as resolution_vendor_name

        | display uuid, id, timestamp, sp, dol_state,
        overall_process_timed_out_flag,
        overall_process_success,
        document_check_vendor,
        address_vendor_name,

        #instantVerify
        resolution_vendor_name,
        resolution_referenceID,
        resolution_transactionID,
        resolution_success,
        resolution_timed_out_flag
      QUERY
    end

    def threat_metrix_query
      <<~QUERY
        filter name = "IdV: doc auth verify proofing results"
        | fields
            properties.user_id as uuid,
            @timestamp as timestamp,
            properties.event_properties.proofing_results.context.stages.threatmetrix.success as tmx_success
        
        | stats max(tmx_success) as max_tmx_success by uuid
        
      QUERY
    end

    def fraud_score_and_attribute_query
      <<~QUERY
        filter name = "idv_threatmetrix_response_body"
        | fields 
          properties.event_properties.response_body.fraudpoint.conversation_id as conversation_id,
          properties.event_properties.response_body.fraudpoint.score as score,
          properties.event_properties.response_body.fraudpoint.friendly_fraud_index as friendly_fraud_index,
          properties.event_properties.response_body.fraudpoint.manipulated_identity_index as manipulated_identity_index,
          properties.event_properties.response_body.fraudpoint.stolen_identity_index as stolen_identity_index,
          properties.event_properties.response_body.fraudpoint.suspicious_activity_index as suspicious_activity_index,
          properties.event_properties.response_body.fraudpoint.synthetic_identity_index as synthetic_identity_index,
          properties.event_properties.response_body.fraudpoint.vulnerable_victim_index as vulnerable_victim_index,
          properties.event_properties.response_body.fraudpoint.risk_indicators_codes as risk_indicators_codes,
          properties.event_properties.response_body.fraudpoint.risk_indicators_descriptions as risk_indicators_descriptions
      QUERY
    end

    def socure_kyc_shadow_query
      <<~QUERY
        fields 
          properties.event_properties.socure_result.success as success,
          properties.event_properties.socure_result.timed_out as timed_out,
          properties.event_properties.socure_result.transaction_id as transaction_id,
          properties.event_properties.socure_result.vendor_name as vendor_name,
          properties.event_properties.socure_result.verified_attributes.0 as v0,
          properties.event_properties.socure_result.verified_attributes.1 as v1,
          properties.event_properties.socure_result.verified_attributes.2 as v2,
          properties.event_properties.socure_result.verified_attributes.3 as v3,
          properties.event_properties.socure_result.verified_attributes.4 as v4,
          properties.event_properties.socure_result.verified_attributes.5 as v5,
          properties.event_properties.socure_result.errors.I352 as I352,
          properties.event_properties.socure_result.errors.I900 as I900,
          properties.event_properties.socure_result.errors.I901 as I901,
          properties.event_properties.socure_result.errors.I902 as I902,
          properties.event_properties.socure_result.errors.I919 as I919,
          properties.event_properties.socure_result.errors.R354 as R354
        | filter name = "idv_socure_shadow_mode_proofing_result"
        | stats count(*) as c
      QUERY
    end

    def socure_kyc_non_shadow_query
      <<~QUERY
        fields @timestamp, @message, @logStream, @log
        | filter name='IdV: doc auth verify proofing results' 
        and properties.event_properties.proofing_results.context.stages.resolution.vendor_name='socure_kyc'
        | sort @timestamp desc
        | stats count(*) as c
      QUERY
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  # Parse command-line options
  options = Reporting::CommandLineOptions.new.parse!(ARGV)
  # Generate the report and output CSVs
  Reporting::ApiTransactionCountReport.new(**options).to_csvs.each do |csv|
    puts csv
  end
end
