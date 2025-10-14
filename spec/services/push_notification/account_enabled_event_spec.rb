require 'rails_helper'

RSpec.describe PushNotification::AccountEnabledEvent do
  include Rails.application.routes.url_helpers

  subject(:event) do
    PushNotification::AccountEnabledEvent.new(user: user)
  end

  let(:user) { build(:user) }

  describe '#event_type' do
    it 'is the RISC event type' do
      expect(event.event_type).to eq(PushNotification::AccountEnabledEvent::EVENT_TYPE)
    end
  end

  describe '#payload' do
    let(:iss_sub) { SecureRandom.uuid }
    let(:iss) { 'issuer' }

    subject(:payload) { event.payload(iss: iss, iss_sub: iss_sub) }

    it 'is a subject with the provided iss_sub ' do
      expect(payload).to eq(
        subject: {
          subject_type: 'iss-sub',
          sub: iss_sub,
          iss: iss,
        },
      )
    end
  end
end
