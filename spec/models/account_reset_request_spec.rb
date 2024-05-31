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
end
