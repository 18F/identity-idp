require 'rails_helper'

describe AccountReset::CancelRequestForUser do
  let(:user) { create(:user) }
  let!(:account_reset_request) { AccountResetRequest.create(user: user, requested_at: 1.hour.ago) }

  subject { described_class.new(user) }

  describe '#call' do
    it 'cancels the account reset request' do
      subject.call

      expect(account_reset_request.reload.cancelled_at).to be_within(1.second).of(Time.zone.now)
    end

    it 'does not cancel account reset requests for a different user' do
      other_user = create(:user)
      other_request = AccountResetRequest.create(user: other_user, requested_at: 1.hour.ago)

      subject.call

      expect(other_request.reload.cancelled_at).to be_nil
    end

    it "sends an email to the user's confirmed email addresses" do

    end
  end
end
