require 'spec_helper'
require 'reporting/cloudwatch_client'

RSpec.describe Reporting::CloudwatchClient do
  let(:wait_duration) { 0 }
  let(:logger) { Logger.new('/dev/null') }
  let(:slice_interval) { 1.day }

  subject(:client) do
    Reporting::CloudwatchClient.new(
      wait_duration: wait_duration,
      logger: logger,
      slice_interval: slice_interval,
    )
  end

  describe '#fetch' do
    let(:from) { }

    context ':slice_interval is falsy' do
      it 'does not split up the interval and queries by the from/to passed in' do
      end
    end

    context ':slice_interval is an interval' do
      it 'splits the query up into the time range' do
        expect(client).to receive(:fetch_one).exactly(2).times
      end
    end
  end
end
