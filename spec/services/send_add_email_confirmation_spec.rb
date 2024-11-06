require 'rails_helper'

RSpec.describe SendAddEmailConfirmation do
  describe '#call' do
    let(:user) { create(:user, confirmed_at: nil) }
    let(:email_address) { user.email_addresses.take }
    let(:request_id) { '1234-abcd' }
    let(:confirmation_token) { 'confirm-me' }

    before do
      allow(Devise).to receive(:friendly_token).once.and_return(confirmation_token)
      email_address.update!(
        confirmed_at: nil,
        confirmation_token: nil,
        confirmation_sent_at: nil,
      )
    end

    subject { described_class.new(user) }
    it 'sends the user an email with a confirmation link and the request id' do
      email_address.update!(confirmed_at: Time.zone.now)

      subject.call(email_address:, request_id:, in_select_email_flow: nil)
      expect_delivered_email_count(1)
      expect_delivered_email(
        to: [user.email_addresses.first.email],
        subject: t('user_mailer.add_email.subject'),
        body: [request_id],
      )
    end
  end
end
