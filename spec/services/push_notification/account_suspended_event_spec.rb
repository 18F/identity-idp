require 'rails_helper'

RSpec.describe PushNotification::AccountSuspendedEvent do
  include Rails.application.routes.url_helpers

  subject(:event) do
    PushNotification::AccountSuspendedEvent.new(user: user)
  end

  let(:user) { build(:user) }

  describe '#event_type' do
    it 'is the RISC event type' do
      expect(event.event_type).to eq(PushNotification::AccountSuspendedEvent::EVENT_TYPE)
    end
  end

  describe '#payload' do
    it 'is a subject' do
      expect(event.payload).to eq(
        subject: {
          subject_type: 'account-suspension',
        },
      )
    end
  end
end
