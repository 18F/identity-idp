require 'rails_helper'

RSpec.describe DeviceDecorator do
  let(:device) { create(:device) }
  subject(:decorator) { DeviceDecorator.new(device) }

  describe '#nice_name' do
    it 'gives a shortened os and browser name' do
      expect(decorator.nice_name).to eq('Chrome 58 on Windows')
    end
  end
end
