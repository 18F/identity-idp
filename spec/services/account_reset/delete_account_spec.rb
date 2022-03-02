require 'rails_helper'

describe AccountReset::DeleteAccount do
  include AccountResetHelper
  let(:user) { create(:user) }

  describe '#call' do
    it 'can be called even if DeletedUser exists' do
      create_account_reset_request_for(user)
      grant_request(user)
      token = AccountResetRequest.where(user_id: user.id).first.granted_token
      Db::DeletedUser::Create.call(user.id)
      AccountReset::DeleteAccount.new(token).call
    end
  end
end
