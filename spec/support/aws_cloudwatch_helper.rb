module AwsCloudwatchHelper
  # Helps mimic Array<Aws::CloudWatchLogs::Types::ResultField>
  # @return [Array<Hash>]
  def to_result_fields(hsh)
    hsh.map do |key, value|
      { field: key, value: value }
    end
  end

  # @param rows [Array<Hash>]
  def stub_cloudwatch_logs(rows)
    query_id = SecureRandom.hex

    stub_const('Reporting::CloudwatchClient::DEFAULT_WAIT_DURATION', 0)

    Aws.config[:cloudwatchlogs] = {
      stub_responses: {
        start_query: { query_id: query_id },
        get_query_results: {
          status: 'Complete',
          results: rows.map { |row| to_result_fields(row) },
        },
      },
    }
  end

  # Stubs multiple separate Cloudwatch queries (in order) to have differente response
  # @param responses [Array<Array<Hash>>]
  def stub_multiple_cloudwatch_logs(*responses)
    stub_const('Reporting::CloudwatchClient::DEFAULT_WAIT_DURATION', 0)

    query_ids = responses.map { SecureRandom.hex }

    Aws.config[:cloudwatchlogs] = {
      stub_responses: {
        start_query: query_ids.map { |query_id| { query_id: query_id } },
        get_query_results: responses.map do |rows|
          {
            status: 'Complete',
            results: rows.map { |row| to_result_fields(row) },
          }
        end,
      },
    }
  end
end
