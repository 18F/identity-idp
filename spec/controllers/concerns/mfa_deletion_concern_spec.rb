require 'rails_helper'

RSpec.describe MfaDeletionConcern do
  controller ApplicationController do
    include MfaDeletionConcern
  end

  let(:user) { create(:user, :fully_registered) }

  before do
    stub_sign_in(user)
  end

  describe '#handle_successful_mfa_deletion' do
    let(:event_type) do
      [:authenticator_disabled, :backup_codes_removed, :phone_removed, :piv_cac_disabled,
       :webauthn_key_removed, :webauthn_platform_removed].sample
    end
    subject(:result) { controller.handle_successful_mfa_deletion(event_type:) }

    it 'does not return a value' do
      expect(result).to be_nil
    end

    it 'creates user event using event_type argument' do
      expect(controller).to receive(:create_user_event_with_disavowal).with(event_type, user)

      result
    end

    it 'revokes remembered device for user' do
      expect(controller).to receive(:revoke_remember_device).with(user)

      result
    end

    it 'sends risc push notification' do
      expect(PushNotification::HttpPush).to receive(:deliver) do |event|
        expect(event.user).to eq(user)
      end

      result
    end

    it 'sends an email confirming deletion' do
      delivery = instance_double(ActionMailer::MessageDelivery, deliver_now_or_later: true)
      mailer = instance_double(UserMailer)

      user.confirmed_email_addresses.each do |email_address|
        allow(UserMailer).to receive(:with).with(
          user: user, email_address: email_address,
        ).and_return(mailer)

        expect(mailer).to receive(:mfa_deleted)
          .with(subject: instance_of(String), disavowal_token: instance_of(String))
          .and_return(delivery)
      end

      result
    end
  end
end
