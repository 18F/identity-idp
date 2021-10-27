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
    let(:user_agent) { 'Chrome/58.0.3029.110 Safari/537.36' }
    let(:uuid) { 'abc123' }
    let(:now) { Time.zone.now }
    let(:old_timestamp) { now - 1.hour }
    let(:device) { create(:device, last_used_at: old_timestamp) }

    it 'updates the last ip and last_used_at' do
      expect { device.update_last_used_ip(remote_ip) }.
        to(change { device.reload.last_used_at.to_i }.from(old_timestamp.to_i).to(now.to_i).
          and(change { device.reload.last_ip }.to(remote_ip)))
    end
  end
end
