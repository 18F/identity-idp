require 'rails_helper'

RSpec.describe AccountReset::FindPendingRequestForUser do
  describe '#call' do
    let(:user) { create(:user) }
    let(:granted_at) { nil }
    let(:cancelled_at) { nil }
    let(:requested_at) { 1.hour.ago }

    let!(:account_reset_request) do
      AccountResetRequest.create(
        user:,
        granted_at:,
        cancelled_at:,
        requested_at:,
      )
    end

    subject { described_class.new(user) }

    context 'when a request exists' do
      it { expect(subject.call).to eq(account_reset_request) }
    end

    context 'when a request does not exist' do
      let!(:account_reset_request) { nil }

      it { expect(subject.call).to be_nil }
    end

    context 'when a request exists, but it has been granted' do
      let(:granted_at) { 1.hour.ago }

      it { expect(subject.call).to be_nil }
    end

    context 'when a request exists, but it is expired' do
      let(:requested_at) { 1.year.ago }

      it { expect(subject.call).to be_nil }
    end

    context 'when a request exists, but it has been cancelled' do
      let(:cancelled_at) { 1.hour.ago }

      it { expect(subject.call).to be_nil }
    end
  end
end
