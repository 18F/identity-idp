require 'rails_helper'

describe ResetPasswordAndNotifyUser do
  let(:email_address) { 'changemypassword@example.com' }
  let(:message) { 'Hello, user.' }

  subject { described_class.new(email_address, message) }

  before do
    allow(subject).to receive(:warn)
  end

  describe '#call' do
    context 'when the user does exist' do
      it 'resets the password and notifies the user' do
        password = 'compromised password'
        user = create(:user, email: email_address, password: password)

        subject.call

        user.reload
        mail = ActionMailer::Base.deliveries.last

        expect(mail.to).to eq([email_address])
        expect(mail.html).to include(message)
        expect(user.valid_password?(password)).to eq(false)
      end
    end

    context 'when the user does not exist' do
      it 'prints a warning' do
        expect(subject).to receive(:warn).with("User '#{email_address}' does not exist")

        subject.call
      end
    end
  end
end
