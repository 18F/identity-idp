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
          'True ID (Selfie)',
          'Instant verify',
          'Phone Finder',
          'Socure (DocV)',
          'Socure (DocV - Selfie)',
          'Socure (KYC)',
          'Fraud Score and Attribute',
          'Threat Metrix (IDV)',
          'Threat Metrix (Auth Only)',
          'LN Emailage',
          'GPO',
          'AAMVA',
          'Socure PhoneRisk (Shadow)',
        ],
        [
          "#{ time_range.begin.to_date} - #{time_range.end.to_date}",
          true_id_table.first,
          true_id_selfie_table.first,
          instant_verify_table.first,
          phone_finder_table.first,
          socure_table.first,
          socure_docv_selfie_table.first,
          socure_kyc_table.first,
          fraud_score_and_attribute_table.first,
          threat_metrix_idv_table.first,
          threat_metrix_auth_only_table.first,
          ln_emailage_table.first,
          gpo_table.first,
          aamva_table.first,
          socure_phonerisk_table.first,
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

    def true_id_selfie_table
      result = fetch_results(query: true_id_selfie_query)
      true_id_selfie_table_count = result.count
      [true_id_selfie_table_count, result]
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

    def socure_docv_selfie_table
      result = fetch_results(query: socure_docv_selfie_query)
      socure_table_count = result.count
      [socure_table_count, result]
    end

    def socure_kyc_table
      result = fetch_results(query: socure_kyc)
      socure_table_count = result.count
      [socure_table_count, result]
    end

    def ln_emailage_table
      result = fetch_results(query: ln_emailage_query)
      ln_emailage_table_count = result.count
      [ln_emailage_table_count, result]
    end

    def instant_verify_table
      result = fetch_results(query: instant_verify_query)
      instant_verify_table_count = result.count
      [instant_verify_table_count, result]
    end

    def threat_metrix_idv_table
      result = fetch_results(query: threat_metrix_idv_query)
      threat_metrix_table_count = result.count
      [threat_metrix_table_count, result]
    end

    def threat_metrix_auth_only_table
      result = fetch_results(query: threat_metrix_auth_only_query)
      threat_metrix_table_count = result.count
      [threat_metrix_table_count, result]
    end

    def fraud_score_and_attribute_table
      result = fetch_results(query: fraud_score_and_attribute_query)
      fraud_score_and_attribute_table_count = result.count
      [fraud_score_and_attribute_table_count, result]
    end

    def gpo_table
      result = fetch_results(query: gpo_query)
      gpo_table_count = result.count
      [gpo_table_count, result]
    end

    def aamva_table
      result = fetch_results(query: aamva_query)
      aamva_table_count = result.count
      [aamva_table_count, result]
    end

    def socure_phonerisk_table
      result = fetch_results(query: socure_phonerisk_query)
      socure_phonerisk_table_count = result.count
      [socure_phonerisk_table_count, result]
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
        | limit 10000
      QUERY
    end

    def true_id_selfie_query
      <<~QUERY
         fields @timestamp, @message, @logStream, @log, id
        | filter name = "IdV: doc auth image upload vendor submitted"
        | filter properties.event_properties.liveness_enabled=1
        | limit 10000

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
        | limit 10000
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
        | limit 10000
      QUERY
    end

    def socure_docv_selfie_query
      <<~QUERY
        #socure (Selfie)
         fields @timestamp, @message, @logStream, @log
        | filter name = "idv_socure_verification_data_requested" | filter properties.event_properties.liveness_enabled=1
        | display timestamp, id
        | limit 10000
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
        | limit 10000
      QUERY
    end

    def threat_metrix_idv_query
      <<~QUERY
        fields @timestamp, @message, @logStream, @log
        | filter name = "IdV: doc auth verify proofing results"
        | display timestamp, id
        | limit 10000
      QUERY
    end

    def threat_metrix_auth_only_query
      <<~QUERY
        filter name = "account_creation_tmx_result"
        | fields
            properties.user_id as uuid,
            @timestamp as timestamp,
         | limit 10000
      QUERY
    end

    def fraud_score_and_attribute_query
      <<~QUERY
        filter name = "idv_threatmetrix_response_body"
        | fields 
          properties.event_properties.response_body.review_status as review_status,
          properties.event_properties.response_body.risk_rating as risk_rating,
          properties.event_properties.response_body.summary_risk_score as summary_risk_score
        | limit 10000
      QUERY
    end

    def socure_kyc
      <<~QUERY
        fields @timestamp, @message, @logStream, @log
        | filter name='IdV: doc auth verify proofing results' 
        and properties.event_properties.proofing_results.context.stages.resolution.vendor_name='socure_kyc'
        | sort @timestamp desc
        | limit 10000
      QUERY
    end

    def ln_emailage_query
      <<~QUERY
         fields @timestamp, @message, @log, id
        | filter name = "account_creation_tmx_result"
        | filter properties.event_properties.response_body.emailage.emailriskscore.responsestatus.status = 'success'
        | display timestamp, id
        | limit 10000
      QUERY
    end

    def gpo_query
      <<~QUERY
         fields @timestamp, @message, @log, id
        |filter name = 'gpo_confirmation_upload' #GPO confirmation records were uploaded for letter sends
        | stats count(*) as gpo_transactions
        | limit 10000
      QUERY
    end

    def aamva_query
      <<~QUERY
        fields @timestamp, @message, @log, id 
        | filter name IN ['IdV: doc auth verify proofing results', ‘idv_state_id_validation’]
        | fields jsonParse(@message) as message
        | unnest message.properties.event_properties.proofing_results.context.stages.state_id into state_id
        | unnest message.properties.event_properties.proofing_results.context.should_proof_state_id into @should_proof_state_id
        | fields state_id.vendor_name as @vendor_name, name, 
         coalesce(@vendor_name,properties.event_properties.vendor_name) as vendor_name ,
         coalesce(@should_proof_state_id,0) as should_proof_state_id
        | filter (name = 'IdV: doc auth verify proofing results' and should_proof_state_id = 1)  or (name = 'idv_state_id_validation')
        | filter vendor_name = 'aamva:state_id'
        | stats count(*) as aamva_transactions_ipp
        | limit 10000
      QUERY
    end

    def socure_phonerisk_query
      <<~QUERY
        fields @timestamp, @message, @log, id
        | filter name IN ["idv_socure_shadow_mode_phonerisk_result"] 
        | stats count(*) as socure_phonerisk_transactions
        | limit 10000
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
