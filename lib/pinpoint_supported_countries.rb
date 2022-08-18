require 'active_support/core_ext/hash/except'
require 'faraday'
require 'nokogiri'
require 'phonelib'

# Scrapes HTML tables from Pinpoint help sites to parse out supported countries, and
# puts them in a format compatible with country_dialing_codes.yml
class PinpointSupportedCountries
  PINPOINT_SMS_URL = 'https://docs.aws.amazon.com/pinpoint/latest/userguide/channels-sms-countries.html'.freeze
  PINPOINT_VOICE_URL = 'https://docs.aws.amazon.com/pinpoint/latest/userguide/channels-voice-countries.html'.freeze

  # The list of countries where we have our sender ID registered
  SENDER_ID_COUNTRIES = %w[
    BY
    EG
    JO
    PH
    TH
  ].to_set.freeze

  CountrySupport = Struct.new(
    :iso_code,
    :name,
    :supports_sms,
    :supports_voice,
    keyword_init: true,
  ) do
    def merge(other)
      self.class.new(**to_h.merge(other.to_h) { |_k, a, b| a || b })
    end
  end

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
    country_dialing_codes = load_country_dialing_codes

    duplicate_iso = country_dialing_codes.
                    group_by(&:iso_code).
                    select { |iso, arr| arr.size > 1 }.
                    keys

    raise "error countries with duplicate iso codes: #{duplicate_iso}" if duplicate_iso.size > 0

    country_dialing_codes.sort_by(&:name).map do |country_dialing_code|
      [
        country_dialing_code.iso_code,
        country_dialing_code.to_h.except(:iso_code).transform_keys(&:to_s),
      ]
    end.to_h
  end

  # @return [Array<CountrySupport>]
  def sms_support
    TableConverter.new(download(PINPOINT_SMS_URL)).
      convert.
      select { |sms_config| sms_config['ISO code'] }. # skip section rows
      map do |sms_config|
        iso_code = sms_config['ISO code']
        supports_sms = case trim_spaces(sms_config['Supports Sender IDs'])
        when 'Registration required1'
          SENDER_ID_COUNTRIES.include?(iso_code)
        when 'Registration required3' # basically only India, has special rules
          true
        else
          true
        end

        CountrySupport.new(
          iso_code: iso_code,
          name: trim_spaces(sms_config['Country or region']),
          supports_sms: supports_sms,
        )
      end
  end

  # @return [Array<CountrySupport>]
  def voice_support
    TableConverter.new(download(PINPOINT_VOICE_URL)).convert.map do |voice_config|
      CountrySupport.new(
        name: trim_spaces(
          voice_config['Country or Region'], # Yes, it is capitalized differently :[
        ),
        supports_voice: true,
      )
    end
  end

  # @return [Array<CountryDialingCode>] combines sms and voice support into one array of configs
  def load_country_dialing_codes
    (sms_support + voice_support).group_by(&:name).map do |_name, configs|
      combined = configs.reduce(:merge)

      iso_code = name_to_iso_code(combined.name) || remap_iso_code(combined.iso_code)
      phone_data = Phonelib.phone_data[iso_code]

      raise "no phone_data for '#{iso_code}', maybe it needs to be remapped?" unless phone_data

      CountryDialingCode.new(
        iso_code: iso_code,
        country_code: country_code(phone_data),
        name: combined.name,
        supports_sms: combined.supports_sms || false,
        supports_voice: combined.supports_voice || false,
      )
    end
  end

  def country_code(phone_data)
    code = phone_data[:country_code]
    code += phone_data[:leading_digits] if digits_only?(phone_data[:leading_digits])
    code
  end

  # AWS docs differ from the standard
  # https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
  def remap_iso_code(iso_code)
    {
      'AN' => 'BQ',
      'BDE' => 'BD',
      'DN' => 'DM',
      'H' => 'HT',
      'TX' => 'TZ',
    }.fetch(iso_code, iso_code)
  end

  # AWS docs have the wrong code for many of these names
  def name_to_iso_code(name)
    {
      'Cambodia' => 'KH',
      'Gibraltar' => 'GI',
      'Ivory Coast' => 'CI',
      'Latvia' => 'LV',
      'Mozambique' => 'MZ',
      'Norway' => 'NO',
      'Slovenia' => 'SI',
      'Tuvalu' => 'TV',
    }[name]
  end

  def trim_spaces(str)
    str.gsub(/\s{2,}/, ' ').gsub(/\s+$/, '')
  end

  def digits_only?(str)
    str.to_i.to_s == str
  end

  # Downloads a URL and prints updates to STDERR
  # rubocop:disable Style/StderrPuts
  def download(url)
    STDERR.print "loading #{url}"
    response = Faraday.get(url)
    STDERR.puts ' (done)'
    response.body
  end
  # rubocop:enable Style/StderrPuts

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
