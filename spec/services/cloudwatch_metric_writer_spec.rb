require 'rails_helper'

RSpec.describe CloudwatchMetricWriter do
  let(:cloudwatch_client) do
    client = instance_double(Aws::CloudWatch::Client)
    allow(client).to receive(:put_metric_data)
    client
  end
  let(:current_sp) { NullServiceProvider.new(issuer: 'cloudwatch-test-sp') }
  let(:request_ial) { 1 }

  let(:expected_dimensions) do
    [
      {
        name: 'ServiceProvider',
        value: 'cloudwatch-test-sp',
      },
      {
        name: 'RequestIAL',
        value: '1',
      },
    ]
  end

  subject do
    described_class.new(
      current_sp: current_sp,
      request_ial: request_ial,
      cloudwatch_client: cloudwatch_client,
    )
  end

  before do
    allow(Identity::Hostdata).to receive(:env).and_return('int')
  end

  describe '#write_metric' do
    it 'writes a cloudwatch metric' do
      expect(cloudwatch_client).to receive(:put_metric_data).with(
        namespace: 'int/idp', # TODO: Drop 'local'
        metric_data: [
          {
            metric_name: 'FunMetric',
            dimensions: expected_dimensions,
            timestamp: instance_of(ActiveSupport::TimeWithZone),
            value: 1,
            unit: 'Count',
          },
        ],
      )

      subject.write_metric('FunMetric')
    end

    it 'includes custom dimensions if they are provided' do
      custom_dimensions = [{ name: 'Custom', value: '9000' }]

      expect(cloudwatch_client).to receive(:put_metric_data).with(
        namespace: 'int/idp', # TODO: Drop 'local'
        metric_data: [
          {
            metric_name: 'FunMetric',
            dimensions: expected_dimensions + custom_dimensions,
            timestamp: instance_of(ActiveSupport::TimeWithZone),
            value: 1,
            unit: 'Count',
          },
        ],
      )

      subject.write_metric('FunMetric', dimensions: custom_dimensions )
    end

    it 'includes a custom value and units if they are provided' do
      custom_value = 500
      custom_unit = 'Terabytes/Second'

      expect(cloudwatch_client).to receive(:put_metric_data).with(
        namespace: 'int/idp', # TODO: Drop 'local'
        metric_data: [
          {
            metric_name: 'FunMetric',
            dimensions: expected_dimensions,
            timestamp: instance_of(ActiveSupport::TimeWithZone),
            value: custom_value,
            unit: custom_unit,
          },
        ],
      )

      subject.write_metric('FunMetric', value: custom_value, unit: custom_unit)
    end
  end
end
