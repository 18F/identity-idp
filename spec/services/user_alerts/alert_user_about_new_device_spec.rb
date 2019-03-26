require 'rails_helper'

describe UserAlerts::AlertUserAboutNewDevice do
  describe '#call' do
    before do
      allow(SmsNewDeviceSignInNotifierJob).to receive(:perform_now)
    end

    let(:user) { create(:user, phone_configurations: phone_configurations) }
    let(:disavowal_token) { 'the_disavowal_token' }
    let(:device) { create(:device, user: user) }
    let(:phone_configurations) do
      [
        create(:phone_configuration, phone: '+1 (202) 123-4567'),
        create(:phone_configuration, phone: '+1 (202) 765-4321'),
      ]
    end

    it 'sends an email to all confirmed email addresses' do
      user.email_addresses.destroy_all
      confirmed_email_addresses = create_list(:email_address, 2, user: user)
      create(:email_address, user: user, confirmed_at: nil)

      allow(UserMailer).to receive(:new_device_sign_in).and_call_original

      described_class.call(user, device, disavowal_token)

      expect(UserMailer).to have_received(:new_device_sign_in).twice
      expect(UserMailer).to have_received(:new_device_sign_in).
        with(confirmed_email_addresses[0],
             instance_of(String),
             instance_of(String),
             disavowal_token)
      expect(UserMailer).to have_received(:new_device_sign_in).
        with(confirmed_email_addresses[1],
             instance_of(String),
             instance_of(String),
             disavowal_token)
    end

    context 'send_new_device_sms is enabled' do
      before do
        allow(Figaro.env).to receive(:send_new_device_sms).and_return('true')
      end

      it 'sends an SMSs to user phones' do
        described_class.call(user, device, disavowal_token)

        expect(SmsNewDeviceSignInNotifierJob).to have_received(:perform_now).
          with(phone: phone_configurations[0].phone)
        expect(SmsNewDeviceSignInNotifierJob).to have_received(:perform_now).
          with(phone: phone_configurations[1].phone)
      end
    end

    context 'send_new_device_sms is disabled' do
      before do
        allow(Figaro.env).to receive(:send_new_device_sms).and_return('false')
      end

      it 'does not send any SMSs' do
        described_class.call(user, device, disavowal_token)

        expect(SmsNewDeviceSignInNotifierJob).to_not have_received(:perform_now)
      end
    end
  end
end
