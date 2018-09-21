require 'rails_helper'

describe AccountReset::GrantRequest do
  include AccountResetHelper

  let(:user) { create(:user) }
  let(:user2) { create(:user) }

  describe '#call' do
    it 'adds a notified at timestamp and granted token to the user' do
      create_account_reset_request_for(user)
      AccountReset::GrantRequest.new(user).call
      arr = AccountResetRequest.find_by(user_id: user.id)
      expect(arr.granted_at).to be_present
      expect(arr.granted_token).to be_present
    end
  end
end
