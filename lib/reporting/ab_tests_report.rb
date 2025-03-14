# frozen_string_literal: true

require 'reporting/cloudwatch_client'
require 'reporting/cloudwatch_query_quoting'

module Reporting
  class AbTestsReport
    attr_reader :ab_test, :time_range

    # @param [AbTest] ab_test
    # @param [Range<Time>] time_range
    def initialize(
      ab_test:,
      time_range:
    )
      @ab_test = ab_test
      @time_range = time_range
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

    def participants_message
      return unless ab_test.persist?
      message = "Total participants: #{participants_count.to_fs(:delimited)}"
      message += " (of #{max_participants.to_fs(:delimited)} maximum)" if max_participants.finite?
      message
    end

    private

    delegate :participants_count, :max_participants, :report, to: :ab_test
    delegate :queries, to: :report

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
      )
    end

    # @return [String]
    def format_as_percent(number)
      format('%.2f%%', number)
    end
  end
end
