require 'rails_helper'

RSpec.describe DeviceDecorator do
  let(:device) { create(:device) }
  subject(:decorator) { DeviceDecorator.new(device) }

  describe '#nice_name' do
    it 'gives a shortened os and browser name' do
      expect(decorator.nice_name).to eq('Chrome 58 on Windows 10')
    end

    it 'does not fail if OS version cannot be parsed' do
      # This user agent currently does not parse the OS version
      user_agent = 'Mozilla/5.0 (X11; CrOS armv7l 11316.165.0) AppleWebKit/537.36 (KHTML, '\
                   'like Gecko) Chrome/72.0.3626.122 Safari/537.36'
      device.user_agent = user_agent

      expect(decorator.nice_name).to eq('Chrome 72 on Chrome OS')
    end
  end
end
