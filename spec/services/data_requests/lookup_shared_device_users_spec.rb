require 'rails_helper'

describe DataRequests::LookupSharedDeviceUsers do
  describe '#call' do
    it 'recursively looks up users sharing devices' do
      user1 = create(:user)
      user2 = create(:user)
      user3 = create(:user)

      cookie_uuid1 = '123abc'
      cookie_uuid2 = '456def'

      create(:device, user: user1, cookie_uuid: cookie_uuid1)
      create(:device, user: user2, cookie_uuid: cookie_uuid1)
      create(:device, user: user2, cookie_uuid: cookie_uuid2)
      create(:device, user: user3, cookie_uuid: cookie_uuid2)

      subject = described_class.new([user1])

      allow(subject).to receive(:warn)

      result = subject.call

      expect(result.keys.length).to eq(2)
      expect(result[cookie_uuid1]).to match_array([user1, user2].map(&:uuid))
      expect(result[cookie_uuid2]).to match_array([user2, user3].map(&:uuid))
    end
  end
end
