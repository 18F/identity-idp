class CloudwatchMetricWriter
  attr_reader :current_sp, :request_ial, :cloudwatch_client

  def initialize(
    current_sp:,
    request_ial:,
    cloudwatch_client: build_cloudwatch_client
  )
    @current_sp = current_sp
    @request_ial = request_ial || 1
    @cloudwatch_client = cloudwatch_client
  end

  def write_metric(name, dimensions: [], value: 1, unit: 'Count')
    return unless Identity::Hostdata.in_datacenter?

    cloudwatch_client.put_metric_data(
      namespace: "#{Identity::Hostdata.env || 'local'}/idp", # TODO: Drop 'local'
      metric_data: [
        {
          metric_name: name,
          dimensions: base_dimenstions + dimensions,
          timestamp: Time.zone.now,
          value: value,
          unit: unit,
        },
      ],
    )
  end

  private

  def base_dimenstions
    [
      {
        name: 'ServiceProvider',
        value: current_sp.issuer || 'NULL',
      },
      {
        name: 'RequestIAL',
        value: request_ial.to_s,
      },
    ]
  end

  def build_cloudwatch_client
    # TODO: Should we have some sort of stubbed or mocked client locally?
    Aws::CloudWatch::Client.new
  end
end
