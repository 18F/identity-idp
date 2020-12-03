module DataRequests
  class WriteCloudwatchLogs
    HEADERS = %w[
      timestamp
      event_name
      success
      multi_factor_auth_method
      service_provider
      ip_address
      user_agent
    ].freeze

    attr_reader :cloudwatch_results, :output_dir

    def initialize(cloudwatch_results, output_dir)
      @cloudwatch_results = cloudwatch_results
      @output_dir = output_dir
    end

    def call
      output_file.puts(HEADERS.join(','))
      cloudwatch_results.each do |row|
        write_row(row)
      end
      output_file.close
    end

    private

    def output_file
      @output_file ||= begin
        output_path = File.join(output_dir, 'logs.csv')
        File.open(output_path, 'w')
      end
    end

    def write_row(row)
      data = JSON.parse(row.message)

      timestamp = data.dig('time')
      event_name = data.dig('name')
      success = data.dig('properties', 'event_properties', 'success')
      multi_factor_auth_method = data.dig(
        'properties', 'event_properties', 'multi_factor_auth_method'
      )
      service_provider = data.dig('properties', 'service_provider')
      ip_address = data.dig('properties', 'user_ip')
      user_agent = data.dig('properties', 'user_agent')

      output_file.puts(
        CSV.generate_line(
          [
            timestamp, event_name, success, multi_factor_auth_method,
            service_provider, ip_address, user_agent
          ],
        ),
      )
    end
  end
end
