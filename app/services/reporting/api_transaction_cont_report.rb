# frozen_string_literal: true

module Reporting
  class ApiTransactionCountReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    def api_transaction_report
      table = []
      table << ['Query Name', 'Result Count']
      table += query_results
      table
    end

    def api_transaction_emailable_report
      EmailableReport.new(
        title: 'API Transaction Count Report (last 30 days)',
        float_as_percent: false,
        precision: 0,
        table: api_transaction_report,
        filename: 'api_transaction_count',
      )
    end

    private

    # Execute all queries and return results as an array of rows
    def query_results
      [
        ['LN Stack', run_query(ln_stack_query)],
        ['TrueID', run_query(trueid_query)],
        ['Acuant', run_query(acuant_query)],
        ['PhoneFinder', run_query(phonefinder_query)],
        ['Socure', run_query(socure_query)],
      ]
    end

    # Query 1: LN Stack
    def ln_stack_query
      <<~SQL
        SELECT 
          properties.user_id AS uuid,
          id,
          cloudwatch_timestamp AS timestamp,
          properties.sp_request.app_differentiator AS dol_state,
          properties.service_provider AS sp,
          properties.event_properties.proofing_results.timed_out AS overall_process_timed_out_flag,
          properties.event_properties.success AS overall_process_success,
          properties.event_properties.proofing_components.document_check AS document_check_vendor,
          properties.event_properties.proofing_results.context.stages.residential_address.vendor_name AS address_vendor_name,
          properties.event_properties.proofing_results.context.stages.resolution.vendor_name AS resolution_vendor_name,
          properties.event_properties.proofing_results.context.stages.resolution.reference AS resolution_referenceID,
          properties.event_properties.proofing_results.context.stages.resolution.transaction_id AS resolution_transactionID,
          properties.event_properties.proofing_results.context.stages.resolution.success AS resolution_success,
          properties.event_properties.proofing_results.context.stages.resolution.timed_out AS resolution_timed_out_flag,
          properties.event_properties.proofing_results.context.stages.state_id.vendor_name AS state_id_vendor_name,
          properties.event_properties.proofing_results.context.stages.state_id.transaction_id AS state_id_transactionID,
          properties.event_properties.proofing_results.context.stages.state_id.success AS state_id_success,
          properties.event_properties.proofing_results.context.stages.state_id.timed_out AS state_id_timed_out_flag,
          properties.event_properties.proofing_results.context.stages.threatmetrix.session_id AS tmx_sessionID,
          properties.event_properties.proofing_results.context.stages.threatmetrix.transaction_id AS tmx_transactionID,
          properties.event_properties.proofing_results.context.stages.threatmetrix.review_status AS tmx_review_status,
          properties.event_properties.proofing_results.context.stages.threatmetrix.success AS tmx_success,
          properties.event_properties.proofing_results.context.stages.threatmetrix.timed_out AS tmx_timed_out_flag
        FROM analytics.logs.events
        WHERE name = 'IdV: doc auth verify proofing results'
          AND cloudwatch_timestamp BETWEEN '#{start_date}' AND '#{end_date}'
      SQL
    end

    # Query 2: TrueID
    def trueid_query
      <<~SQL
        SELECT 
          properties.user_id AS uuid,
          id,
          cloudwatch_timestamp AS timestamp,
          properties.sp_request.app_differentiator AS dol_state,
          properties.event_properties.success AS success,
          properties.service_provider AS sp,
          properties.event_properties.billed AS billed,
          properties.event_properties.conversation_id AS conversation_id,
          properties.event_properties.decision_product_status AS decision_status,
          properties.event_properties.product_status AS product_status,
          properties.event_properties.reference AS referenceID,
          properties.event_properties.remaining_submit_attempts AS remaining_submit_attempts,
          properties.event_properties.request_id AS request_id,
          properties.event_properties.submit_attempts AS submit_attempts,
          properties.event_properties.transaction_status AS transaction_status,
          properties.event_properties.vendor AS vendor
        FROM analytics.logs.events
        WHERE name = 'IdV: doc auth image upload vendor submitted'
          AND cloudwatch_timestamp BETWEEN '#{start_date}' AND '#{end_date}'
      SQL
    end

    # Query 3: Acuant
    def acuant_query
      <<~SQL
        SELECT 
          properties.user_id AS uuid,
          id,
          cloudwatch_timestamp AS timestamp,
          properties.sp_request.app_differentiator AS dol_state,
          properties.service_provider AS sp,
          properties.event_properties.use_alternate_sdk AS use_alternate_sdk,
          properties.event_properties.success AS success,
          properties.event_properties.acuant_version AS acuant_version,
          properties.event_properties.captureAttempts AS captureAttempts,
          CASE 
            WHEN name LIKE '%front%' THEN 'front'
            ELSE 'back'
          END AS side
        FROM analytics.logs.events
        WHERE name IN ('Frontend: IdV: front image clicked', 'Frontend: IdV: back image clicked')
          AND cloudwatch_timestamp BETWEEN '#{start_date}' AND '#{end_date}'
      SQL
    end

    # Query 4: PhoneFinder
    def phonefinder_query
      <<~SQL
        SELECT 
          properties.user_id AS uuid,
          id,
          cloudwatch_timestamp AS timestamp,
          properties.sp_request.app_differentiator AS dol_state,
          properties.service_provider AS sp,
          properties.event_properties.vendor.transaction_id AS phoneFinder_transactionID,
          properties.event_properties.vendor.reference AS phoneFinder_referenceID,
          properties.event_properties.success AS success,
          properties.event_properties.area_code AS area_code,
          properties.event_properties.country_code AS country_code,
          properties.event_properties.phone_fingerprint AS phone_fingerprint
        FROM analytics.logs.events
        WHERE name = 'IdV: phone confirmation vendor'
          AND cloudwatch_timestamp BETWEEN '#{start_date}' AND '#{end_date}'
      SQL
    end

    # Query 5: Socure
    def socure_query
      <<~SQL
        SELECT 
          properties.user_id AS uuid,
          id,
          cloudwatch_timestamp AS timestamp,
          properties.sp_request.app_differentiator AS dol_state,
          properties.event_properties.success AS success,
          properties.service_provider AS sp,
          properties.event_properties.decision.value AS decision_result,
          properties.event_properties.docv_transaction_token AS docv_transaction_token,
          properties.event_properties.reference_id AS reference_id,
          properties.event_properties.submit_attempts AS submit_attempts
        FROM analytics.logs.events
        WHERE name = 'idv_socure_verification_data_requested'
          AND cloudwatch_timestamp BETWEEN '#{start_date}' AND '#{end_date}'
      SQL
    end

    # Helper to execute a query and return the result count
    def run_query(query)
      Reports::BaseReport.transaction_with_timeout do
        result = ActiveRecord::Base.connection.execute(query)
        result.count
      end
    end

    def start_date
      (report_date - 30.days).beginning_of_day
    end

    def end_date
      report_date.end_of_day
    end
  end
end
