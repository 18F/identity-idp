require 'rails_helper'

describe CreateVerifiedAccountEvent do
  let(:user) do
    create(:user) do |user|
      user.events.create(event_type: :account_verified)
    end
  end

  let(:eventless_user) { create(:user) }

  context '#call' do
    it 'adds an `aacount_verified` event if the user does not have one' do
      expect(eventless_user.events.account_verified.size).to be 0
      CreateVerifiedAccountEvent.new(eventless_user).call
      expect(eventless_user.events.account_verified.size).to be 1
    end

    it 'does not create duplicate events' do
      CreateVerifiedAccountEvent.new(user).call
      expect(user.events.account_verified.size).to be 1
    end
  end
end
