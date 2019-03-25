require 'rails_helper'

describe Recover::CreateRecoverRequest do
  let(:subject) { described_class }
  let(:user_id) { 1 }
  let(:old_timestamp) { Time.zone.now - 1.year }

  it 'creates a new request if one does not exist' do
    result = subject.call(user_id)
    expect(result).to be_kind_of(AccountRecoveryRequest)

    account_recovery_request = AccountRecoveryRequest.find_by(user_id: user_id)

    expect(account_recovery_request.request_token).to be_present
    expect(account_recovery_request.requested_at).to be_present
  end

  it 'update a request if one already exists' do
    AccountRecoveryRequest.create(user_id: user_id,
                                  request_token: 'foo',
                                  requested_at: old_timestamp)

    result = subject.call(user_id)
    expect(result).to be_kind_of(AccountRecoveryRequest)

    account_recovery_request = AccountRecoveryRequest.find_by(user_id: user_id)
    expect(account_recovery_request.request_token).to be_present
    expect(account_recovery_request.request_token).to_not eq('foo')
    expect(account_recovery_request.request_token).to be_present
    expect(account_recovery_request.requested_at).to_not eq(old_timestamp)
  end
end
