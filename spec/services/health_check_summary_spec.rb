require 'rails_helper'

RSpec.describe HealthCheckSummary do
  let(:healthy) { true }
  let(:result) { 'some result' }

  subject(:health_check_summary) do
    HealthCheckSummary.new(
      healthy:,
      result:,
    )
  end

  describe '#healthy?' do
    it 'is healthy' do
      expect(health_check_summary.healthy?).to eq(healthy)
    end
  end

  describe '#as_json' do
    it 'is the JSON representation' do
      expect(health_check_summary.as_json).to eq(
        'healthy' => healthy,
        'result' => result,
      )
    end
  end
end
