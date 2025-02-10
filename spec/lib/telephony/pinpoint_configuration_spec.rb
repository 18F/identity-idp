require 'rails_helper'

RSpec.describe Telephony::PinpointConfiguration do
  context '#add_sms_config' do
    it 'raises if the same country code is used in both longcode and shortcode configuration' do
      config = Telephony::PinpointConfiguration.new
      expect do
        config.add_sms_config do |sms|
          sms.country_code_shortcodes = { 'PR' => '123456' }
          sms.country_code_longcode_pool = { 'PR' => ['+1 (939) 456-7890'] }
        end.to raise_error(
          'cannot configure a country code for both longcodes and a shortcode',
        )
      end
    end
  end
end
