require 'rails_helper'

RSpec.describe PushNotification::ReproofCompletedEvent do
  include Rails.application.routes.url_helpers

  subject(:event) do
    PushNotification::ReproofCompletedEvent.new(user:)
  end

  let(:user) { build(:user) }

  describe '#event_type' do
    it 'is the RISC event type' do
      expect(event.event_type).to eq(PushNotification::ReproofCompletedEvent::EVENT_TYPE)
    end
  end

  describe '#payload' do
    let(:iss_sub) { SecureRandom.uuid }

    subject(:payload) { event.payload(iss_sub:) }

    it 'is a subject with the provided iss_sub ' do
      expect(payload).to eq(
        subject: {
          subject_type: 'iss-sub',
          sub: iss_sub,
          iss: root_url,
        },
      )
    end
  end
end
