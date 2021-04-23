require 'rails_helper'

describe Db::DeletedUser::Create do
  subject { described_class }

  it 'does nothing if the user does not exist' do
    subject.call(1)
    expect(DeletedUser.count).to eq(0)
  end

  it 'creates a deleted_user and retains some fields' do
    user = create(:user)
    subject.call(user.id)

    expect(DeletedUser.count).to eq(1)
    deleted_user = DeletedUser.first
    expect(deleted_user.user_id).to eq(user.id)
  end

  it 'fails gracefully if we try to insert the same user twice and returns the deleted user' do
    user = create(:user)
    deleted_user1 = subject.call(user.id)
    deleted_user2 = subject.call(user.id)
    expect(deleted_user1).to eq(deleted_user2)
  end
end
