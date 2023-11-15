require 'rails_helper'

RSpec.describe PushNotification::AccountReinstatedEvent do
  include Rails.application.routes.url_helpers

  subject(:event) do
    PushNotification::AccountReinstatedEvent.new(user: user)
  end

  let(:user) { build(:user) }

  describe '#event_type' do
    it 'is the RISC event type' do
      expect(event.event_type).to eq(PushNotification::AccountReinstatedEvent::EVENT_TYPE)
    end
  end

  describe '#payload' do
    let(:iss_sub) { SecureRandom.uuid }

    subject(:payload) { event.payload(iss_sub: iss_sub) }

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
