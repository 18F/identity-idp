require 'rails_helper'

RSpec.describe PushNotification::EmailChangedEvent do
  subject(:event) do
    PushNotification::EmailChangedEvent.new(
      user:,
      email:,
    )
  end

  let(:user) { build(:user) }
  let(:email) { Faker::Internet.safe_email }

  describe '#event_type' do
    it 'is the RISC event type' do
      expect(event.event_type).to eq(PushNotification::EmailChangedEvent::EVENT_TYPE)
    end
  end

  describe '#payload' do
    it 'is a subject with an email' do
      expect(event.payload).to eq(
        subject: {
          subject_type: 'email',
          email:,
        },
      )
    end
  end
end
