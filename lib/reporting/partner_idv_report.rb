# frozen_string_literal: true

module Reporting
  class PartnerIdvReport
    REDSHIFT_QUERY = <<~SQL.freeze
      WITH params AS (
          SELECT
              :month_start_calendar_id as month_start_calendar_id,
              :service_provider_id as service_provider_id
      )
      SELECT
          sp_ref.issuer,
          sp_ref.service_provider_name,
          sp_ref.agency_name,
          sp_data.start_service_provider_id,
          sp_data.month_start_date_actual,
          sp_data.month_start_calendar_id,
          sp_data.count_inauthentic_doc,
          sp_data.count_facial_mismatch,
          sp_data.count_invalid_attributes_dl_dos,
          sp_data.count_ssn_dob_deceased,
          sp_data.count_address_other_not_found,
          sp_data.count_pending_lg99_likely_fraud,
          sp_data.count_stayed_blocked,
          sp_data.count_fraud_alert,
          sp_data.count_suspicious_phone,
          sp_data.count_lack_phone_ownership,
          sp_data.count_wrong_phone_type,
          sp_data.count_blocked_by_ipp_fraud,
          sp_data.count_pass_via_lg99,
          sp_data.count_pass_online_finalization,
          sp_data.count_pass_ipp_online_portion,
          sp_data.count_pass_via_letter,
          sp_data.count_doc_auth_ux,
          sp_data.count_selfie_ux,
          sp_data.count_dob_incorrect,
          sp_data.count_ssn_incorrect,
          sp_data.count_identity_not_found,
          sp_data.count_friction_during_otp,
          sp_data.count_doc_auth_technical_issue,
          sp_data.count_resolution_technical_issues,
          sp_data.count_doc_auth_processing_issue
      FROM marts.sp_idv_outcomes_monthly sp_data
      INNER JOIN marts.service_providers sp_ref
          ON sp_data.start_service_provider_id = sp_ref.service_provider_id
      CROSS JOIN params p
      WHERE sp_data.start_service_provider_id = p.service_provider_id
          AND sp_data.month_start_calendar_id = p.month_start_calendar_id
    SQL

    POLL_INTERVAL_SECONDS = 2
    MAX_POLL_SECONDS = 300
    FINISHED_STATUSES = %w[FINISHED FAILED ABORTED].freeze

    attr_reader :service_provider_id, :month_start_calendar_id

    # @param [Integer] service_provider_id
    # @param [Integer] month_start_calendar_id
    # @param [String] cluster_id Redshift cluster identifier
    # @param [String] database Redshift database name
    # @param [String] db_user Redshift database user
    def initialize(
      service_provider_id:,
      month_start_calendar_id:,
      cluster_id: IdentityConfig.store.redshift_cluster_id,
      database: IdentityConfig.store.redshift_database,
      db_user: IdentityConfig.store.redshift_db_user
    )
      @service_provider_id = service_provider_id
      @month_start_calendar_id = month_start_calendar_id
      @cluster_id = cluster_id
      @database = database
      @db_user = db_user
    end

    # @return [String] JSON string of query results
    def results_json
      JSON.generate(fetch_results)
    end

    # @return [Array<Hash>] array of hashes with column names as keys
    def fetch_results
      statement_id = execute_statement
      wait_for_completion(statement_id)
      rows_to_hashes(redshift_client.get_statement_result(id: statement_id))
    end

    def redshift_client
      @redshift_client ||= begin
        require 'aws-sdk-redshiftdataapiservice'
        Aws::RedshiftDataAPIService::Client.new
      end
    end

    private

    def execute_statement
      response = redshift_client.execute_statement(
        cluster_identifier: @cluster_id,
        database: @database,
        db_user: @db_user,
        sql: REDSHIFT_QUERY,
        parameters: [
          { name: 'service_provider_id', value: @service_provider_id.to_s },
          { name: 'month_start_calendar_id', value: @month_start_calendar_id.to_s },
        ],
      )
      response.id
    end

    def wait_for_completion(statement_id)
      deadline = Time.now + MAX_POLL_SECONDS

      loop do
        if Time.now > deadline
          raise "Redshift statement #{statement_id} did not finish within " \
                "#{MAX_POLL_SECONDS} seconds"
        end

        status_response = redshift_client.describe_statement(id: statement_id)
        status = status_response.status

        if FINISHED_STATUSES.include?(status)
          if status != 'FINISHED'
            raise "Redshift statement #{statement_id} ended with status " \
                  "#{status}: #{status_response.error}"
          end
          break
        end

        sleep(POLL_INTERVAL_SECONDS)
      end
    end

    def rows_to_hashes(result)
      column_names = result.column_metadata.map(&:name)
      result.records.map do |row|
        column_names.zip(row.map { |field| extract_field_value(field) }).to_h
      end
    end

    def extract_field_value(field)
      return nil if field.is_null
      return field.long_value if field.long_value
      return field.double_value if field.double_value
      return field.boolean_value if !field.boolean_value.nil? && field.string_value.nil?

      field.string_value
    end
  end
end
