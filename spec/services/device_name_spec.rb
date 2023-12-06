require 'rails_helper'

RSpec.describe DeviceName do
  describe '#device_name' do
    let(:device) { create(:device) }
    it 'gives a shortened os and browser name' do
      name = DeviceName.from_user_agent(device.user_agent)
      expect(name).to eq('Chrome 58 on Windows 10')
    end
  end
end
