require 'rails_helper'

describe DeviceTracking::DeviceName do
  subject { described_class }
  let(:parser) { UserAgentParser::Parser }
  let(:device) { create(:device) }

  it 'gives a shortened os and browser name' do
    result = subject.call(parser.new, device)

    expect(result).to eq('Chrome 58 on Windows 10')
  end
end
