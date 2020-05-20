require 'rails_helper'

describe 'PendingAccountResetRequestConcern' do
  include PendingAccountResetRequestConcern
  include AccountResetHelper

  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }

  context '#pending_account_reset_request' do
    it "returns a user's pending request" do
      create_account_reset_request_for(user)
      expect(pending_account_reset_request(user)).not_to eq nil
    end

    # rubocop:disable Rails/SkipsModelValidations
    it 'returns nil if the user has no pending request' do
      create_account_reset_request_for(user)
      AccountResetRequest.where(user_id: user.id).update_all(
        cancelled_at: Time.zone.now,
        granted_at: Time.zone.now - 10.minutes,
      )
      expect(pending_account_reset_request(user)).to eq nil
    end
    # rubocop:enable Rails/SkipsModelValidations
  end
end
