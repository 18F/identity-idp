require 'rails_helper'

RSpec.describe DeviceCookie do
  let(:user_agent) { 'A computer on the internet' }
  let(:ip_address) { '4.4.4.4' }
  let(:existing_device_cookie) { 'existing_device_cookie' }
  let(:cookie_jar) do
    {
      device: existing_device_cookie,
    }.with_indifferent_access.tap do |cookie_jar|
      allow(cookie_jar).to receive(:permanent).and_return({})
    end
  end
  let(:request) do
    double(
      remote_ip: ip_address,
      user_agent: user_agent,
      cookie_jar: cookie_jar,
    )
  end
  let(:user) { create(:user, :fully_registered) }
  let(:device) { create(:device, user: user, cookie_uuid: existing_device_cookie) }

  before do
    # Memoize user and device before specs run
    user
    device
  end
  describe '.device_cookie' do
    it 'returns true if a matching device cookie is present' do
      cookies = request.cookie_jar
      device_present = DeviceCookie.check_for_new_device(cookies, user).present?
      expect(device_present).to eq(true)
    end
  end
end
