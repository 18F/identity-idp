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
end
