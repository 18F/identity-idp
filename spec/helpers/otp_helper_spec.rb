require 'rails_helper'

describe OtpHelper do
  describe '#phone_confirmation_instructions' do
    let(:number) { '***-***-1212' }
    context 'with SMS as the delivery method' do
      it 'returns SMS instructions' do
        helper.instance_variable_set(:@delivery_method, 'sms')
        helper.instance_variable_set(:@phone_number, number)

        output = t('instructions.2fa.confirm_code_sms', number: number)
        expect(helper.phone_confirmation_instructions).to eq(output)
      end
    end

    context 'with voice as the delivery method' do
      it 'returns voice instructions' do
        helper.instance_variable_set(:@delivery_method, 'voice')
        helper.instance_variable_set(:@phone_number, number)

        output = t('instructions.2fa.confirm_code_voice', number: number)

        expect(helper.phone_confirmation_instructions).to eq(output)
      end
    end
  end

  describe '#fallback_2fa_links' do
    before do
      allow(helper).to receive(:current_user).and_return(User.new)
    end

    context 'with totp enabled' do
      before do
        allow(helper.current_user).to receive(:totp_enabled?).and_return(true)
      end

      it 'returns voice and optional auth app links when delivery is sms' do
        helper.instance_variable_set(:@delivery_method, 'sms')

        expect(helper.fallback_2fa_links).to match(/phone call/)
        expect(helper.send(:totp_option_link)).not_to be_blank
      end

      it 'returns sms and optional auth app links when delivery is voice' do
        helper.instance_variable_set(:@delivery_method, 'voice')

        expect(helper.fallback_2fa_links).to match(/text message/)
        expect(helper.send(:totp_option_link)).not_to be_blank
      end
    end

    context 'without totp enabled' do
      it 'returns voice link when delivery is sms' do
        helper.instance_variable_set(:@delivery_method, 'sms')

        expect(helper.fallback_2fa_links).to match(/phone call/)
        expect(helper.send(:totp_option_link)).to be_blank
      end

      it 'returns sms link when delivery is voice' do
        helper.instance_variable_set(:@delivery_method, 'voice')

        expect(helper.fallback_2fa_links).to match(/text message/)
        expect(helper.send(:totp_option_link)).to be_blank
      end
    end
  end

  it 'returns a link to the phone delivery page if method is recovery code' do
    helper.instance_variable_set(:@delivery_method, 'recovery-code')
    output = helper.fallback_2fa_links

    expect(output).to have_xpath("//a[@href='#{user_two_factor_authentication_path}']")
  end

  it 'returns an empty string by default' do
    expect(helper.fallback_2fa_links).to be_blank
  end
end
