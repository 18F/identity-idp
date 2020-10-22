require 'active_support/core_ext/hash/except'
require 'active_model/serializers/json'
require 'faraday'
require 'nokogiri'
require 'phonelib'

class PinpointSupportedCountries
  PINPOINT_SMS_URL = 'https://docs.aws.amazon.com/pinpoint/latest/userguide/channels-sms-countries.html'.freeze
  PINPOINT_VOICE_URL = 'https://docs.aws.amazon.com/pinpoint/latest/userguide/channels-voice-countries.html'.freeze

  CountrySupport = Struct.new(
    :iso_code,
    :name,
    :supports_sms,
    :supports_voice,
    keyword_init: true,
  )

  # Corresponds to a block in country_dialing_codes.yml
  CountryDialingCode = Struct.new(
    :iso_code,
    :country_code,
    :name,
    :supports_sms,
    :supports_voice,
    keyword_init: true,
  )

  # @return [Hash<String, String>] a hash that matches the structure of country_dialing_codes.yml
  def run
    sms = TableConverter.new(Faraday.get(PINPOINT_SMS_URL).body).convert.map do |sms_config|
      CountrySupport.new(
        iso_code: sms_config['ISO code'],
        name: sms_config['Country or region'],
        # The list is of supported countries, but ones that are 'Yes1' require sender IDs,
        # which we do not have (so we do not support them)
        supports_sms: sms_config['Supports sender IDs'] != 'Yes1',
      )
    end

    voice = TableConverter.new(Faraday.get(PINPOINT_VOICE_URL).body).convert.map do |voice_config|
      CountrySupport.new(
        name: voice_config['Country or Region'], # Yes, it is capitalized differently :[
        supports_voice: true,
      )
    end

    country_dialing_codes = (sms + voice).group_by(&:name).map do |_name, (config1, config2)|
      iso_code = remap_iso_code(config1.iso_code || config2&.iso_code)
      phone_data = Phonelib.phone_data[iso_code]

      raise "no phone_data for '#{iso_code}', maybe it needs to be remapped?" unless phone_data

      CountryDialingCode.new(
        iso_code: iso_code,
        country_code: phone_data[:country_code],
        name: config1.name || config2&.name,
        supports_sms: config1.supports_sms || config2&.supports_sms || false,
        supports_voice: config1.supports_voice || config2&.supports_voice || false,
      )
    end

    country_dialing_codes.sort_by(&:name).map do |country_dialing_code|
      [ country_dialing_code.iso_code, country_dialing_code.to_h.except(:iso_code).as_json ]
    end.to_h
  end

  def remap_iso_code(iso_code)
    {
      'AN' => 'BQ',
    }.fetch(iso_code, iso_code)
  end

  # Parses a <table> into into an array of hashes, where the <td> values are
  # keyed by the corresponding <td>
  class TableConverter
    attr_reader :html

    def initialize(html)
      @html = html
    end

    # @return [Array<Hash<String, String>>]
    def convert
      doc = Nokogiri::HTML(html)

      table = doc.xpath('//table').first

      headings = []
      table.xpath('//thead/tr').each do |row|
        row.xpath('th').each do |cell|
          headings << cell.text
        end
      end

      table.xpath('tr').map do |row|
        values = row.xpath('td').map(&:text)

        headings.zip(values).to_h
      end
    end
  end
end
