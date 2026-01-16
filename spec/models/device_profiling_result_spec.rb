require 'rails_helper'

RSpec.describe DeviceProfilingResult do
  describe 'profiling types' do
    it 'includes account_creation type' do
      expect(DeviceProfilingResult::PROFILING_TYPES).to include(:account_creation)
    end
  end

  describe '#rejected?' do
    let(:user) { create(:user) }

    context 'when result is rejected' do
      let(:result) { create(:device_profiling_result, :rejected, user: user) }

      it 'returns true' do
        expect(result.rejected?).to be true
      end
    end

    context 'when result is approved' do
      let(:result) { create(:device_profiling_result, user: user) }

      it 'returns false' do
        expect(result.rejected?).to be false
      end
    end

    context 'when result is pending' do
      let(:result) { create(:device_profiling_result, :pending, user: user) }

      it 'returns false' do
        expect(result.rejected?).to be false
      end
    end
  end
end
