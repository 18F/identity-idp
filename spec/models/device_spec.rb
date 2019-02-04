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
end
