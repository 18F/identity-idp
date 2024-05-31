require 'rails_helper'

RSpec.describe AccountResetRequest do
  it { is_expected.to belong_to(:user) }

  let(:subject) { AccountResetRequest.new }

  describe '#granted_token_valid?' do
    it 'returns false if the token does not exist' do
      subject.granted_token = nil
      subject.granted_at = Time.zone.now

      expect(subject.granted_token_valid?).to eq(false)
    end

    it 'returns false if the token is expired' do
      subject.granted_token = '123'
      subject.granted_at = Time.zone.now - 7.days

      expect(subject.granted_token_valid?).to eq(false)
    end

    it 'returns true if the token is valid' do
      subject.granted_token = '123'
      subject.granted_at = Time.zone.now

      expect(subject.granted_token_valid?).to eq(true)
    end
  end

  describe '#granted_token_expired?' do
    it 'returns false if the token does not exist' do
      subject.granted_token = nil
      subject.granted_at = nil

      expect(subject.granted_token_expired?).to eq(false)
    end

    it 'returns true if the token is expired' do
      subject.granted_token = '123'
      subject.granted_at = Time.zone.now - 7.days

      expect(subject.granted_token_expired?).to eq(true)
    end

    it 'returns false if the token is valid' do
      subject.granted_token = '123'
      subject.granted_at = Time.zone.now

      expect(subject.granted_token_expired?).to eq(false)
    end
  end

  describe '.pending_request_for' do
    subject(:pending_request) { AccountResetRequest.pending_request_for(user) }

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

    context 'when a request exists' do
      it { expect(pending_request).to eq(account_reset_request) }
    end

    context 'when a request does not exist' do
      let!(:account_reset_request) { nil }

      it { expect(pending_request).to be_nil }
    end

    context 'when a request exists, but it has been granted' do
      let(:granted_at) { 1.hour.ago }

      it { expect(pending_request).to be_nil }
    end

    context 'when a request exists, but it is expired' do
      let(:requested_at) { 1.year.ago }

      it { expect(pending_request).to be_nil }
    end

    context 'when a request exists, but it has been cancelled' do
      let(:cancelled_at) { 1.hour.ago }

      it { expect(pending_request).to be_nil }
    end

    context 'fraud user' do
      let(:user) { create(:user, :fraud_review_pending) }
      let(:user2) { create(:user, :fraud_rejection) }
      context 'when a request exists, and it hasnt been granted yet but over a day' do
        let(:requested_at) { 30.hours.ago }

        it { expect(pending_request).to eq(account_reset_request) }
      end
      context 'when a request has expired' do
        let(:requested_at) { 1.year.ago }

        it { expect(pending_request).to be_nil }
      end
    end
  end

  describe '.cancel!' do
    let(:now) { Time.zone.now }
    let(:user) { create(:user) }
    let!(:account_reset_request) do
      AccountResetRequest.create(user: user, requested_at: 1.hour.ago)
    end
    subject(:cancel!) { account_reset_request.cancel!(now: now) }

    it 'cancels the account reset request' do
      cancel!

      expect(account_reset_request.reload.cancelled_at.to_i).to eq(now.to_i)
    end

    it 'does not cancel account reset requests for a different user' do
      other_user = create(:user)
      other_request = AccountResetRequest.create(user: other_user, requested_at: 1.hour.ago)

      cancel!

      expect(other_request.reload.cancelled_at).to be_nil
    end

    it "sends an email to the user's confirmed email addresses and phone numbers" do
      email_address1 = user.email_addresses.first
      email_address2 = create(:email_address, user: user)

      phone_config1 = create(:phone_configuration, user: user)
      phone_config2 = create(:phone_configuration, user: user)

      expect(Telephony).to receive(:send_account_reset_cancellation_notice).
        with(to: phone_config1.phone, country_code: 'US')
      expect(Telephony).to receive(:send_account_reset_cancellation_notice).
        with(to: phone_config2.phone, country_code: 'US')

      cancel!

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
  end
end
