require 'rails_helper'

RSpec.describe HeartbeatJob, type: :job do
  describe '#perform' do
    it 'returns true' do
      result = HeartbeatJob.new.perform

      expect(result).to eq true
    end

    it 'logs goodjob queue metrics' do
      expect(Rails.logger).to receive(:info) do |str|
        msg = JSON.parse(str, symbolize_names: true)
        expect(msg).to eq(
          name: 'queue_metric.good_job',
          num_finished: 0,
          num_unfinished: 0,
          num_running: 0,
          num_errors: 0,
        )
      end

      HeartbeatJob.new.perform
    end
  end
end
