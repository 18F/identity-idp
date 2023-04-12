require 'rails_helper'

RSpec.describe DeletedUser do
  describe '.create_from_user' do
    it 'does nothing if the user does not exist' do
      DeletedUser.create_from_user(nil)
      expect(DeletedUser.count).to eq(0)
    end

    it 'creates a deleted_user and retains some fields' do
      user = create(:user)
      DeletedUser.create_from_user(user)

      expect(DeletedUser.count).to eq(1)
      deleted_user = DeletedUser.first
      expect(deleted_user.user_id).to eq(user.id)
    end

    it 'fails gracefully if we try to insert the same user twice and returns the deleted user' do
      user = create(:user)
      DeletedUser.create_from_user(user)
      DeletedUser.create_from_user(user)
      expect(DeletedUser.find_by!(user_id: user.id)).to_not be_nil
    end

    it 'fails gracefully if we try to insert the same user while in a transaction' do
      user = create(:user)
      ActiveRecord::Base.transaction do
        DeletedUser.create_from_user(user)
      end
      ActiveRecord::Base.transaction do
        DeletedUser.create_from_user(user)
      end
      expect(DeletedUser.where(user_id: user.id).count).to eq(1)
    end
  end
end
