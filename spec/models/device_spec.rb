require 'rails_helper'

describe Device do
  it { is_expected.to belong_to(:user) }

  describe 'validations' do
    let(:device) { build_stubbed(:device) }

    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:cookie_uuid) }
    it { is_expected.to validate_presence_of(:last_used_at) }
    it { is_expected.to validate_presence_of(:last_ip) }

    it 'factory built event is valid' do
      expect(device).to be_valid
    end
  end

  describe '#update_last_used_ip' do
    let(:user) { create(:user) }
    let(:remote_ip) { '1.2.3.4' }
    let(:old_timestamp) { 1.hour.ago }
    let(:device) { create(:device, last_used_at: old_timestamp) }

    it 'updates the last ip and last_used_at' do
      freeze_time do
        now = Time.zone.now
        device.update_last_used_ip(remote_ip)
        expect(device.last_ip).to eq(remote_ip)
        expect(device.last_used_at.to_i).to eq(now.to_i)
      end
    end
  end
end
