require 'rails_helper'

RSpec.describe HeartbeatJob, type: :job do
  describe '#perform' do
    it 'returns true' do
      result = HeartbeatJob.new.perform

      expect(result).to eq true
    end
  end
end
