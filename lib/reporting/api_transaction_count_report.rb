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
    def initialize(time_range:)
      @time_range = time_range || previous_week_range
    end

    def as_tables
      [
        api_transaction_count,
      ]
    end

    def as_emailable_reports
      [
        Reporting::EmailableReport.new(
          title: 'API Transaction Count Report',
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
          'Fraud Score and Attribute',
          'Threat Metrix',
        ],
        [
          time_range.begin.to_date.to_s + ' - ' + time_range.end.to_date.to_s,
          true_id_table.first,
          instant_verify_table.first,
          phone_finder_table.first,
          socure_table.first,
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
      Rails.logger.info("Time range: #{time_range.begin.to_date} to #{time_range.end.to_date}")

      results = cloudwatch_client.fetch(
        query:,
        from: time_range.begin.to_date,
        to: time_range.end.to_date,
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
        progress: false,
        ensure_complete_logs: false,
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
        | fields properties.user_id as uuid, id, @timestamp as timestamp,
        properties.sp_request.app_differentiator as dol_state, properties.service_provider as sp,

        #OVERALL
        properties.event_properties.proofing_results.timed_out as overall_process_timed_out_flag,
        properties.event_properties.success as overall_process_success,
        properties.event_properties.proofing_components.document_check as document_check_vendor,
        properties.event_properties.proofing_results.context.stages.residential_address.vendor_name as address_vendor_name,


        #TMX --> threatmetrix
        properties.event_properties.proofing_results.context.stages.threatmetrix.review_status as tmx_review_status,
        properties.event_properties.proofing_results.context.stages.threatmetrix.session_id as tmx_sessionID,
        properties.event_properties.proofing_results.context.stages.threatmetrix.success as tmx_success,
        properties.event_properties.proofing_results.context.stages.threatmetrix.timed_out as tmx_timed_out_flag,
        properties.event_properties.proofing_results.context.stages.threatmetrix.transaction_id as tmx_transactionID

        | display uuid, id, timestamp, sp, dol_state,
        overall_process_timed_out_flag,
        overall_process_success,
        document_check_vendor,
        address_vendor_name
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
