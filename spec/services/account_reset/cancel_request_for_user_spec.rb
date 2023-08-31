require 'rails_helper'

RSpec.describe AccountReset::CancelRequestForUser do
  let(:user) { create(:user) }
  let!(:account_reset_request) { AccountResetRequest.create(user: user, requested_at: 1.hour.ago) }

  subject { described_class.new(user) }

  describe '#call' do
    let(:now) { Time.zone.now }
    it 'cancels the account reset request' do
      subject.call(now: now)

      expect(account_reset_request.reload.cancelled_at.to_i).to eq(now.to_i)
    end

    it 'does not cancel account reset requests for a different user' do
      other_user = create(:user)
      other_request = AccountResetRequest.create(user: other_user, requested_at: 1.hour.ago)

      subject.call

      expect(other_request.reload.cancelled_at).to be_nil
    end

    it "sends an email to the user's confirmed email addresses" do
      notify_user_of_cancellation = instance_double(AccountReset::NotifyUserOfRequestCancellation)
      expect(AccountReset::NotifyUserOfRequestCancellation).to receive(:new).
        with(user).
        and_return(notify_user_of_cancellation)
      expect(notify_user_of_cancellation).to receive(:call)

      subject.call
    end
  end
end
