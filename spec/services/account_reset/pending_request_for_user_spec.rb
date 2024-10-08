require 'rails_helper'

RSpec.describe AccountReset::PendingRequestForUser do
  describe '#get_account_reset_request' do
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
      let(:user2) { create(:user, :fraud_rejection) }
      context 'when a request exists, and it hasnt been granted yet but over a day' do
        let(:requested_at) { 30.hours.ago }

        it { expect(subject.get_account_reset_request).to eq(account_reset_request) }
      end
      context 'when a request has expired' do
        let(:requested_at) { 1.year.ago }

        it { expect(subject.get_account_reset_request).to be_nil }
      end
    end
  end
end
