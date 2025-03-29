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
  class APITransactionCountReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :time_range

    QUERY_DEFINITIONS = [
      { title: 'Singular Vendor', method: :singular_vendor_query },
      { title: 'True ID', method: :true_id_query },
      { title: 'Acuant', method: :acuant_query },
      { title: 'Phone Finder', method: :phone_finder_query },
      { title: 'Socure', method: :socure_query },
    ].freeze

    # @param [Range<Time>] time_range
    def initialize(time_range:)
      @time_range = time_range
    end

    def as_tables
      Rails.logger.info('Generating API Transaction Count Report tables...')
      tables = queries.map { |query| table_for_query(query) }
      Rails.logger.info('API Transaction Count Report tables generated successfully.')
      tables
    end

    def to_csvs
      as_tables.map do |table|
        CSV.generate do |csv|
          table.each { |row| csv << row }
        end
      end
    end

    private

    def queries
      QUERY_DEFINITIONS.map do |definition|
        { title: definition[:title], query: send(definition[:method]) }
      end
    end

    def table_for_query(query)
      query_data = fetch_results(query: query[:query])
      return [[query[:title]], ['No data available']] if query_data.empty?

      headers = column_labels(query_data.first)
      rows = query_data.map(&:values)

      [
        [query[:title]], # Add the query title as the first row
        headers,
        *rows,
      ]
    end

    def fetch_results(query:)
      cloudwatch_client.fetch(query:, from: time_range.begin, to: time_range.end)
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

    # Query definitions for fetching API transaction counts
    def singular_vendor_query
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
        properties.event_properties.proofing_results.context.stages.resolution.vendor_name as resolution_vendor_name,

        #aamva --> state_id
        properties.event_properties.proofing_results.context.stages.state_id.success as state_id_success,
        properties.event_properties.proofing_results.context.stages.state_id.timed_out as state_id_timed_out_flag,
        properties.event_properties.proofing_results.context.stages.state_id.transaction_id as state_id_transactionID,
        properties.event_properties.proofing_results.context.stages.state_id.vendor_name as state_id_vendor_name,

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
        address_vendor_name,

        #instantVerify
        resolution_vendor_name,
        resolution_referenceID,
        resolution_transactionID,
        resolution_success,
        resolution_timed_out_flag,

        #aamva
        state_id_vendor_name,
        state_id_transactionID,
        state_id_success,
        state_id_timed_out_flag,

        #TMX
        tmx_sessionID,
        tmx_transactionID,
        tmx_review_status,
        tmx_success,
        tmx_timed_out_flag
      QUERY
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

    def acuant_query
      <<~QUERY
        #Acuant
        filter name in ["Frontend: IdV: front image clicked","Frontend: IdV: back image clicked"]
        | fields properties.user_id as uuid, id, @timestamp as timestamp,
        properties.sp_request.app_differentiator as dol_state,
        properties.service_provider as sp, properties.event_properties.use_alternate_sdk as use_alternate_sdk,
        properties.event_properties.success as success, properties.event_properties.acuant_version as acuant_version, properties.event_properties.captureAttempts as captureAttempts,
        replace(replace(strcontains(name, "front"),"1","front"),"0","back") as side
        | display uuid, id, timestamp, sp, dol_state, side, acuant_version, captureAttempts, use_alternate_sdk

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
  end
end

if __FILE__ == $PROGRAM_NAME
  # Parse command-line options
  options = Reporting::CommandLineOptions.new.parse!(ARGV)

  # Generate the report and output CSVs
  Reporting::APITransactionCountReport.new(**options).to_csvs.each do |csv|
    puts csv
  end
end
