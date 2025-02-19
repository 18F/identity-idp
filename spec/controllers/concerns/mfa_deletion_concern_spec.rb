require 'rails_helper'

RSpec.describe MfaDeletionConcern do
  controller ApplicationController do
    include MfaDeletionConcern
  end

  let(:user) { create(:user, :fully_registered) }

  before do
    stub_sign_in(user)
  end

  describe '#handle_successful_mfa_deletion' do
    let(:event_type) { Event.event_types.keys.sample.to_sym }
    subject(:result) { controller.handle_successful_mfa_deletion(event_type:) }

    it 'does not return a value' do
      expect(result).to be_nil
    end

    it 'creates user event using event_type argument' do
      expect(controller).to receive(:create_user_event).with(event_type)

      result
    end

    it 'revokes remembered device for user' do
      expect(controller).to receive(:revoke_remember_device).with(user)

      result
    end

    it 'sends risc push notification' do
      expect(PushNotification::HttpPush).to receive(:deliver) do |event|
        expect(event.user).to eq(user)
      end

      result
    end
  end
end
