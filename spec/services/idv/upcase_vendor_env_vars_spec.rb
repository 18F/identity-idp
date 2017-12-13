require 'rails_helper'

describe Idv::UpcaseVendorEnvVars do
  describe '#call' do
    before do
      allow(Figaro.env).to receive(:profile_proofing_vendor).and_return('aamva')
      allow(Figaro.env).to receive(:phone_proofing_vendor).and_return('equifax')
      stub_const 'ENV', ENV.to_h.merge(
        'equifax_thing' => 'some value',
        'aamva_thing' => 'other value'
      )
    end

    it 'sets UPPER case value equal to existing ENV var' do
      expect(ENV['FOO_THING']).to eq nil

      subject.call

      expect(ENV['equifax_thing']).to eq 'some value'
      expect(ENV['EQUIFAX_THING']).to eq 'some value'
      expect(ENV['aamva_thing']).to eq 'other value'
      expect(ENV['AAMVA_THING']).to eq 'other value'
    end
  end
end
