require 'rails_helper'

RSpec.describe AccountReset::PendingRequestForUser do
  let(:user) { create(:user) }
  let(:granted_at) { nil }
  let(:cancelled_at) { nil }
  let(:requested_at) { 1.hour.ago }
  let!(:account_reset_request) do
    AccountResetRequest.create(
      user: user,
      granted_at: granted_at,
      cancelled_at: cancelled_at,
      requested_at: requested_at,
    )
  end
  subject { described_class.new(user) }

  describe '#get_account_reset_request' do
    context 'when a request exists' do
      it { expect(subject.get_account_reset_request).to eq(account_reset_request) }
    end

    context 'when a request does not exist' do
      let!(:account_reset_request) { nil }

      it { expect(subject.get_account_reset_request).to be_nil }
    end

    context 'when a request exists, but it has been granted' do
      let(:granted_at) { 1.hour.ago }

      it { expect(subject.get_account_reset_request).to be_nil }
    end

    context 'when a request exists, but it is expired' do
      let(:requested_at) { 1.year.ago }

      it { expect(subject.get_account_reset_request).to be_nil }
    end

    context 'when a request exists, but it has been cancelled' do
      let(:cancelled_at) { 1.hour.ago }

      it { expect(subject.get_account_reset_request).to be_nil }
    end

    context 'fraud user' do
      let(:user) { create(:user, :fraud_review_pending) }
      context 'when a valid request exists for a user pending fraud review' do
        let(:requested_at) { 30.hours.ago }

        it { expect(subject.get_account_reset_request).to eq(account_reset_request) }
      end
      context 'when a request has expired' do
        let(:requested_at) { 1.year.ago }

        it { expect(subject.get_account_reset_request).to be_nil }
      end
    end
  end

  describe '#cancel_account_reset_request!' do
    let(:now) { Time.zone.now }
    it 'cancels the account reset request' do
      subject.cancel_account_reset_request!(
        account_reset_request_id: account_reset_request.id,
        cancelled_at: now,
      )

      expect(account_reset_request.reload.cancelled_at.to_i).to eq(now.to_i)
    end

    it "sends an email to the user's confirmed email addresses" do
      expect(subject).to receive(:notify_user!)

      subject.cancel_account_reset_request!(
        account_reset_request_id: account_reset_request.id,
        cancelled_at: now,
      )
    end

    context 'with no existing pending request' do
      let(:cancelled_at) { Time.zone.now }
      it 'fails gracefully and does not send email' do
        expect(subject).to_not receive(:notify_user!)

        expect do
          subject.cancel_account_reset_request!(
            account_reset_request_id: account_reset_request.id,
            cancelled_at: now,
          )
        end.to_not change { account_reset_request.cancelled_at }
      end
    end
  end

  describe '#notify_user!' do
    it 'sends an email to all of the user email addresses' do
      email_address1 = user.email_addresses.first
      email_address2 = create(:email_address, user: user)

      subject.notify_user!

      expect_delivered_email_count(2)
      expect_delivered_email(
        to: [email_address1.email],
        subject: t('user_mailer.account_reset_cancel.subject'),
      )
      expect_delivered_email(
        to: [email_address2.email],
        subject: t('user_mailer.account_reset_cancel.subject'),
      )
    end

    it 'sends a text to all of the user phone numbers' do
      phone_config1 = create(:phone_configuration, user: user)
      phone_config2 = create(:phone_configuration, user: user)

      expect(Telephony).to receive(:send_account_reset_cancellation_notice)
        .with(to: phone_config1.phone, country_code: 'US')
      expect(Telephony).to receive(:send_account_reset_cancellation_notice)
        .with(to: phone_config2.phone, country_code: 'US')

      subject.notify_user!
    end
  end
end
