require 'rails_helper'

describe AccountReset::DeleteAccount do
  include AccountResetHelper
  let(:user) { create(:user) }

  describe '#call' do
    it 'can be called even if DeletedUser exists' do
      create_account_reset_request_for(user)
      grant_request(user)
      token = AccountResetRequest.where(user_id: user.id).first.granted_token
      DeletedUser.create_from_user(user)
      AccountReset::DeleteAccount.new(token).call
    end

    context 'when user.confirmed_at is nil' do
      let(:user) { create(:user, confirmed_at: nil) }

      it 'does not blow up' do
        create_account_reset_request_for(user)
        grant_request(user)

        token = AccountResetRequest.where(user_id: user.id).first.granted_token
        expect { AccountReset::DeleteAccount.new(token).call }.to_not raise_error

        expect(User.find_by(id: user.id)).to be_nil
      end
    end
  end
end
