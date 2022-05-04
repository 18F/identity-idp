require 'rails_helper'

describe SendSignUpEmailConfirmation do
  describe '#call' do
    let(:user) { create(:user, confirmed_at: nil) }
    let(:email_address) { user.email_addresses.take }
    let(:request_id) { '1234-abcd' }
    let(:instructions) { 'do the things' }
    let(:confirmation_token) { 'confirm-me' }

    before do
      allow(Devise).to receive(:friendly_token).once.and_return(confirmation_token)
      email_address.update!(
        confirmed_at: nil,
        confirmation_token: nil,
        confirmation_sent_at: nil,
      )
      user.reload
    end

    subject { described_class.new(user) }

    it 'sends the user an email with a confirmation link and the request id' do
      email_address.update!(confirmed_at: Time.zone.now)
      mail = double
      expect(mail).to receive(:deliver_now_or_later)
      expect(UserMailer).to receive(:email_confirmation_instructions).with(
        user,
        email_address.email,
        confirmation_token,
        request_id: request_id,
        instructions: instructions,
      ).and_return(mail)

      subject.call(request_id: request_id, instructions: instructions)
    end

    context 'when resetting a password' do
      it 'sends an email with a link to try another email if the current email is unconfirmed' do
        mail = double
        expect(mail).to receive(:deliver_now_or_later)
        expect(UserMailer).to receive(:unconfirmed_email_instructions).with(
          user,
          email_address.email,
          confirmation_token,
          request_id: request_id,
          instructions: instructions,
        ).and_return(mail)

        subject.call(
          request_id: request_id,
          instructions: instructions,
          password_reset_requested: true,
        )
      end
    end

    it 'updates the confirmation values on the email address for the user' do
      subject.call(request_id: request_id)

      expect(user.reload.email_addresses.count).to eq(1)
      expect(email_address.reload.email).to eq(user.email)
      expect(email_address.confirmation_token).to eq(confirmation_token)
      expect(email_address.confirmation_sent_at).to be_within(5.seconds).of(Time.zone.now)
      expect(email_address.confirmed_at).to eq(nil)
    end

    context 'when the user already has a confirmation token' do
      let(:email_address) do
        invalid_confirmation_sent_at =
          Time.zone.now - (IdentityConfig.store.add_email_link_valid_for_hours.hours.to_i + 1)

        create(
          :email_address,
          confirmation_token: 'old-token',
          confirmation_sent_at: invalid_confirmation_sent_at,
          confirmed_at: nil,
          user: build(:user, email: nil),
        )
      end
      let(:user) { email_address.user }

      it 'regenerates a token if the token is expired' do
        mail = double
        expect(mail).to receive(:deliver_now_or_later)

        expect(UserMailer).to receive(:email_confirmation_instructions).with(
          user, email_address.email, confirmation_token, instance_of(Hash)
        ).and_return(mail)

        subject.call

        expect(email_address.reload.confirmation_token).to eq(confirmation_token)
        expect(email_address.confirmation_sent_at).to be_within(5.seconds).of(Time.zone.now)
      end
    end
  end
end
