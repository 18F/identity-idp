require 'rails_helper'

RSpec.describe DeviceName do
  describe '.device_name' do
    let(:user_agent) {}
    let(:device) { create(:device, user_agent:) }
    subject(:name) { DeviceName.from_user_agent(device.user_agent) }

    context 'with a user agent producing a reliable OS version' do
      let(:user_agent) do
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_2_1) AppleWebKit/605.1.15 (KHTML, like Gecko) ' \
          'Version/17.2 Safari/605.1.15'
      end

      it 'gives a shortened browser name with operating system version' do
        expect(name).to eq('Safari 17 on macOS 14')
      end
    end

    context 'with a user agent not producing a reliable OS version' do
      let(:user_agent) do
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) ' \
          'Chrome/120.0.0.0 Safari/537.36 Edg/120.0.2210.121'
      end

      it 'gives a shortened browser name with unversioned operating system' do
        expect(name).to eq('Microsoft Edge 120 on Windows')
      end
    end
  end
end
