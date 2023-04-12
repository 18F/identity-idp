require 'rails_helper'

describe PhoneNumberCapabilities do
  let(:phone) { '+1 (703) 555-5000' }
  let(:phone_confirmed) { false }
  subject(:capabilities) { PhoneNumberCapabilities.new(phone, phone_confirmed: phone_confirmed) }

  describe '#supports?' do
    let(:method) { nil }
    subject(:result) { capabilities.supports?(method) }

    context 'sms' do
      let(:method) { :sms }

      context 'sms is supported' do
        it { should eq(true) }
      end

      context 'sms is unsupported' do
        let(:phone) { '+84 091 234 56 78' }

        it { should eq(false) }
      end
    end

    context 'voice' do
      let(:method) { :voice }

      context 'voice is supported' do
        it { should eq(true) }
      end

      context 'voice is unsupported' do
        let(:phone) { '+1 (441) 295-9644' }

        it { should eq(false) }
      end
    end

    context 'unknown method' do
      let(:method) { :unknown }
      subject(:result) { nil }

      it 'should raise an error' do
        expect { capabilities.supports?(method) }.to raise_error('Unknown method=unknown')
      end
    end
  end

  describe '#supports_all?' do
    let(:methods) { [:sms] }
    subject(:result) { capabilities.supports_all?(methods) }

    context 'sms is supported, voice is unsupported' do
      let(:phone) { '+1 (306) 234-5678' }

      it { should eq(true) }
    end

    context 'voice is supported, sms is unsupported' do
      let(:phone) { '+84 091 234 56 78' }

      it { should eq(false) }
    end

    context 'both sms and voice are supported' do
      it { should eq(true) }
    end
  end

  describe '#sms_only?' do
    context 'voice is supported' do
      it { expect(subject.sms_only?).to eq(false) }
    end

    context 'Bahamas number' do
      let(:phone) { '+1 (242) 327-0143' }
      it { expect(subject.sms_only?).to eq(true) }
    end

    context 'Bermuda number' do
      let(:phone) { '+1 (441) 295-9644' }
      it { expect(subject.sms_only?).to eq(true) }
    end

    context 'United Kingdom number' do
      let(:phone) { '+44 661-289325' }
      it { expect(subject.sms_only?).to eq(true) }
    end

    context "phonelib returns nil or a 2-letter country code that doesn't match our YAML" do
      let(:phone) { '703-555-1212' }
      it { expect(subject.sms_only?).to eq(false) }
    end
  end

  describe '#supports_sms?' do
    subject(:supports_sms?) { capabilities.supports_sms? }

    context 'US number' do
      let(:phone) { '+1 (703) 555-5000' }
      it { is_expected.to eq(true) }
    end

    context 'Bermuda number' do
      let(:phone) { '+1 (441) 295-9644' }
      it { is_expected.to eq(true) }
    end

    context 'Iraq number that is unconfirmed' do
      let(:phone_confirmed) { false }
      let(:phone) { '+964 (703) 555-5000' }
      it { is_expected.to eq(false) }
    end
  end

  describe '#supports_voice?' do
    subject(:supports_sms?) { capabilities.supports_voice? }

    context 'US number' do
      let(:phone) { '+1 (703) 555-5000' }
      it { is_expected.to eq(true) }
    end

    context 'Bermuda number' do
      let(:phone) { '+1 (441) 295-9644' }
      it { is_expected.to eq(false) }
    end

    context 'Philippines number that is confirmed' do
      let(:phone_confirmed) { true }
      let(:phone) { '+63 (703) 555-5000' }
      it { is_expected.to eq(true) }
    end

    context 'Philippines number that is unconfirmed' do
      let(:phone_confirmed) { false }
      let(:phone) { '+63 (703) 555-5000' }
      it { is_expected.to eq(false) }
    end
  end

  describe '#unsupported_location' do
    it 'returns the name of the unsupported country (Bahamas)' do
      locality = PhoneNumberCapabilities.new(
        '+1 (242) 327-0143',
        phone_confirmed: false,
      ).unsupported_location

      expect(locality).to eq('Bahamas')
    end

    it 'returns the name of the unsupported country (Bermuda)' do
      locality = PhoneNumberCapabilities.new(
        '+1 (441) 295-9644',
        phone_confirmed: false,
      ).unsupported_location

      expect(locality).to eq('Bermuda')
    end

    context 'phonelib returns default country' do
      it 'returns the default country' do
        locality = PhoneNumberCapabilities.new(
          '703-555-1212',
          phone_confirmed: false,
        ).unsupported_location

        expect(locality).to eq('United States')
      end
    end
  end

  it 'has valid configuration' do
    # we should never have supports_voice as false and supports_voice_unconfirmed as true

    PhoneNumberCapabilities::INTERNATIONAL_CODES.each do |country, support|
      expect(support['supports_voice']).to eq true if support['supports_voice_unconfirmed']
    end
  end

  describe '.load_config' do
    subject(:config) { PhoneNumberCapabilities.load_config }

    it 'loads the config' do
      expect(config).to eq(YAML.load_file(Rails.root.join('config', 'country_dialing_codes.yml')))
    end

    context 'when there are country_phone_number_overrides' do
      before do
        allow(IdentityConfig.store).to receive(:country_phone_number_overrides).and_return(
          'AD' => {
            'supports_sms' => false,
          },
          'AE' => {
            'supports_voice' => false,
          },
        )
      end

      it 'overrides the YAML but does not erase values', :aggregate_failures do
        expect(config['AD']['supports_sms']).to eq(false) # override
        expect(config['AD']['supports_voice']).to eq(false) # existing
        expect(config['AE']['supports_sms']).to eq(false) # existing
        expect(config['AE']['supports_voice']).to eq(false) # override
      end
    end
  end
end
