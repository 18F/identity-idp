require 'spec_helper'
# require 'rails_helper'
require 'pinpoint_supported_countries'

RSpec.describe PinpointSupportedCountries do
  before do
      stub_request(:get, PinpointSupportedCountries::PINPOINT_SMS_URL).
        to_return(body: sms_table)
      stub_request(:get, PinpointSupportedCountries::PINPOINT_VOICE_URL).
        to_return(body: voice_table)

    stub_const('STDERR', StringIO.new)
  end

  subject(:countries) { PinpointSupportedCountries.new }

  let(:sms_table) do
    <<-HTML
      <table>
        <thead>
          <tr>
            <th>Country or region</th>
            <th>ISO code</th>
            <th>Supports sender IDs</th>
            <th>Supports two-way SMS (Amazon Pinpoint only)</th>
          </tr>
        </thead>
        <tr>
          <td>Argentina</td>
          <td>AR</td>
          <td></td>
          <td>Yes</td>
        </tr>
        <tr>
          <td>Australia</td>
          <td>AU</td>
          <td>Yes</td>
          <td>Yes</td>
        </tr>
        <tr>
          <td>Belarus</td>
          <td>BY</td>
          <td>Yes<sup><a href="#sms-support-note-1">1</a></sup></td>
          <td></td>
        </tr>
      </table>
    HTML
  end

  let(:voice_table) do
    <<-HTML
      <table>
        <thead>
          <tr>
            <th>Country or Region</th>
            <th>Local address required?</th>
            <th>Supports SMS?</th>
          </tr>
        </thead>
        <tr>
          <td>Argentina</td>
          <td>Yes</td>
          <td>No</td>
        </tr>
        <tr>
          <td>Australia</td>
          <td>Yes</td>
          <td>No</td>
        </tr>
      </table>
    HTML
  end

  describe '#run' do
    it 'returns a hash that matches the structure of country_dialing_codes.yml' do
      expect(countries.run).to eq YAML.load <<-STR
        AR:
          country_code: '54'
          name: Argentina
          supports_sms: true
          supports_voice: true
        AU:
          country_code: '61'
          name: Australia
          supports_sms: true
          supports_voice: true
        BY:
          country_code: '375'
          name: Belarus
          supports_sms: false
          supports_voice: false
      STR
    end
  end

  describe '#sms_support' do
    # rubocop:disable Layout/LineLength
    it 'parses the SMS page from poinpoint an array of configs' do
      expect(countries.sms_support).to eq [
        PinpointSupportedCountries::CountrySupport.new(iso_code: 'AR', name: 'Argentina', supports_sms: true),
        PinpointSupportedCountries::CountrySupport.new(iso_code: 'AU', name: 'Australia', supports_sms: true),
        PinpointSupportedCountries::CountrySupport.new(iso_code: 'BY', name: 'Belarus', supports_sms: false),
      ]
    end
    # rubocop:enable Layout/LineLength
  end

  describe '#voice_support' do
    it 'parses the voice page from poinpoint an array of configs' do
      expect(countries.voice_support).to eq [
        PinpointSupportedCountries::CountrySupport.new(name: 'Argentina', supports_voice: true),
        PinpointSupportedCountries::CountrySupport.new(name: 'Australia', supports_voice: true),
      ]
    end
  end

  describe '#country_dialing_codes' do
    # rubocop:disable Layout/LineLength
    it 'combines sms and voice support and country code into a shared config' do
      expect(countries.country_dialing_codes).to eq [
        PinpointSupportedCountries::CountryDialingCode.new(country_code: '54', iso_code: 'AR', name: 'Argentina', supports_sms: true, supports_voice: true),
        PinpointSupportedCountries::CountryDialingCode.new(country_code: '61', iso_code: 'AU', name: 'Australia', supports_sms: true, supports_voice: true),
        PinpointSupportedCountries::CountryDialingCode.new(country_code: '375', iso_code: 'BY', name: 'Belarus', supports_sms: false, supports_voice: false),
      ]
    end
    # rubocop:enable Layout/LineLength
  end

  describe '#country_code' do
    it 'adds the leading digits if they are all digits' do
      expect(countries.country_code(country_code: '1', leading_digits: '2345')).to eq('12345')
    end

    it 'is only the country code if the leading digits have a regex' do
      expect(countries.country_code(country_code: '1', leading_digits: '2[3]4')).to eq('1')
    end
  end

  describe PinpointSupportedCountries::CountrySupport do
    describe '#merge' do
      it 'combines two structs by ||-ing the attributes' do
        a = PinpointSupportedCountries::CountrySupport.new(
          iso_code: 'US',
          supports_sms: true,
        )

        b = PinpointSupportedCountries::CountrySupport.new(
          iso_code: 'US',
          name: 'United States',
          supports_voice: true,
        )

        expect(a.merge(b)).to eq PinpointSupportedCountries::CountrySupport.new(
          iso_code: 'US',
          name: 'United States',
          supports_sms: true,
          supports_voice: true,
        )
      end
    end
  end

  describe PinpointSupportedCountries::TableConverter do
    describe '#convert' do
      let(:html) do
        <<-HTML
          <html>
            <body>
              <div>
                <table>
                  <thead>
                    <tr>
                      <th>First</th>
                      <th>Second</th>
                      <th>Third</th>
                    </tr>
                  </thead>
                  <tr>
                    <td>a</td>
                    <td>b</td>
                    <td>c</td>
                  </tr>
                  <tr>
                    <td>d</td>
                    <td>e</td>
                    <td>f</td>
                  </tr>
                </table>
              </div>
            </body>
          </html>
        HTML
      end

      subject(:converter) { PinpointSupportedCountries::TableConverter.new(html) }

      it 'converts an HTML table into an array of hashes' do
        expect(converter.convert).to eq [
          { 'First' => 'a', 'Second' => 'b', 'Third' => 'c' },
          { 'First' => 'd', 'Second' => 'e', 'Third' => 'f' },
        ]
      end
    end
  end
end
