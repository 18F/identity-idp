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
      CSV.open(File.join(output_dir, 'logs.csv'), 'w') do |csv|
        csv << HEADERS
        cloudwatch_results.each do |row|
          csv << build_row(row)
        end
      end
    end

    private

    def build_row(row)
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

      [
        timestamp,
        event_name,
        success,
        multi_factor_auth_method,
        service_provider,
        ip_address,
        user_agent
      ]
    end
  end
end
