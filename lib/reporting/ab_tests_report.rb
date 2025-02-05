# frozen_string_literal: true

require 'reporting/cloudwatch_client'
require 'reporting/cloudwatch_query_quoting'

module Reporting
  class AbTestsReport
    attr_reader :queries, :time_range

    # @param [Array<String>] queries
    # @param [Range<Time>] time_range
    def initialize(
      queries:,
      time_range:,
      verbose: false
    )
      @queries = queries
      @time_range = time_range
      @verbose = verbose
    end

    def verbose?
      @verbose
    end

    def as_tables
      queries.map(&method(:table_for_query))
    end

    def as_emailable_reports
      queries.map do |query|
        Reporting::EmailableReport.new(
          title: query.title,
          table: table_for_query(query),
        )
      end
    end

    def table_for_query(query)
      query_data = fetch_results(query: query.query)
      headers = column_labels(query_data.first)
      rows = query_data.map(&:values)

      [
        headers,
        *format_rows(rows, headers, query.row_labels),
      ]
    end

    def format_rows(rows, headers, row_labels)
      if row_labels
        rows = rows.each_with_index.map do |value, index|
          [row_labels[index], *value.slice(1)]
        end
      end

      headers.each_index.select { |i| headers[i] =~ /percent/i }.each do |percent_index|
        rows.each { |row| row[percent_index] = format_as_percent(row[percent_index]) }
      end

      rows
    end

    def fetch_results(query:)
      cloudwatch_client.fetch(query:, from: time_range.begin, to: time_range.end)
    end

    def column_labels(row)
      row.keys
    end

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        progress: false,
        ensure_complete_logs: false,
        logger:,
      )
    end

    def logger
      Logger.new(STDERR) if verbose?
    end

    # @return [String]
    def format_as_percent(number)
      format('%.2f%%', number)
    end
  end
end
