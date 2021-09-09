require 'rails_helper'

describe UserAlerts::AlertUserAboutPersonalKeySignIn do
  describe '#call' do
    it 'sends sms and emails to confirmed addresses' do
      user = create(:user)
      disavowal_token = 'asdf1234'
      user.email_addresses.destroy_all
      confirmed_email_addresses = create_list(:email_address, 2, user: user)
      create(:email_address, user: user, confirmed_at: nil)
      phone_configurations = [
        create(:phone_configuration, user: user, phone: '(202) 111-1111'),
        create(:phone_configuration, user: user, phone: '(202) 222-2222'),
      ]

      allow(UserMailer).to receive(:personal_key_sign_in).and_call_original
      allow(Telephony).to receive(:send_personal_key_sign_in_notice)

      response = described_class.call(user, disavowal_token)

      expect(UserMailer).to have_received(:personal_key_sign_in).twice
      expect(UserMailer).to have_received(:personal_key_sign_in).
        with(user, confirmed_email_addresses[0].email, disavowal_token: disavowal_token)
      expect(UserMailer).to have_received(:personal_key_sign_in).
        with(user, confirmed_email_addresses[1].email, disavowal_token: disavowal_token)
      expect(Telephony).to have_received(:send_personal_key_sign_in_notice).
        with(to: phone_configurations[0].phone, country_code: 'US')
      expect(Telephony).to have_received(:send_personal_key_sign_in_notice).
        with(to: phone_configurations[1].phone, country_code: 'US')

      expect(response.to_h[:emails]).to eq(2)
      expect(response.to_h[:sms_message_ids].size).to eq(2)
    end
  end
end
