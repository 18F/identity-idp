require 'rails_helper'

RSpec.describe GoodJobV4ReadyJob, type: :job do
  describe '#perform' do
    it 'logs goodjob v4 readiness' do
      expect(Rails.logger).to receive(:info) do |str|
        msg = JSON.parse(str, symbolize_names: true)
        expect(msg).to eq(
          {
            name: 'good_job_v4_ready',
            ready: GoodJob.v4_ready?,
          },
        )
      end

      GoodJobV4ReadyJob.new.perform
    end
  end
end
