describe EmailSecondFactor do
  describe '.transmit' do
    let(:user) { build_stubbed(:user, otp_secret_key: 'lzmh6ekrnc5i6aaq') }

    it 'calls EmailSecondFactorMailer with :otp sms_type' do
      message_delivery = instance_double(ActionMailer::MessageDelivery)

      expect(EmailSecondFactorMailer).to receive(:your_code_is).with(user).
        and_return(message_delivery)

      expect(message_delivery).to receive(:deliver_later)

      EmailSecondFactor.transmit(user)
    end

    it 'sends the OTP via email' do
      expect { EmailSecondFactor.transmit(user) }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end
