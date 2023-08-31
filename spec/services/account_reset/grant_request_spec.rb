require 'rails_helper'

RSpec.describe AccountReset::GrantRequest do
  include AccountResetHelper

  let(:user) { create(:user) }
  let(:user2) { create(:user) }

  describe '#call' do
    it 'adds a notified at timestamp and granted token to the user' do
      create_account_reset_request_for(user)

      result = AccountReset::GrantRequest.new(user).call
      arr = AccountResetRequest.find_by(user_id: user.id)
      expect(arr.granted_at).to be_present
      expect(arr.granted_token).to be_present
      expect(result).to eq true
    end

    context 'with a currently valid token' do
      it 'returns false and does not update the request' do
        create_account_reset_request_for(user)
        AccountReset::GrantRequest.new(user).call

        arr = AccountResetRequest.find_by(user_id: user.id)
        result = AccountReset::GrantRequest.new(user).call
        expect(result).to eq false
        expect(arr.granted_at).to eq(arr.reload.granted_at)
        expect(arr.granted_token).to eq(arr.reload.granted_token)
      end
    end
  end
end
