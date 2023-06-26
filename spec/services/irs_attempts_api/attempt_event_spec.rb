require 'rails_helper'

RSpec.describe IrsAttemptsApi::AttemptEvent do
  let(:jti) { 'test-unique-id' }
  let(:iat) { Time.zone.now.to_i }
  let(:event_type) { 'test-event' }
  let(:session_id) { 'test-session-id' }
  let(:occurred_at) { Time.zone.now.round }
  let(:event_metadata) { { 'foo' => 'bar' } }

  subject do
    described_class.new(
      jti: jti,
      iat: iat,
      event_type: event_type,
      session_id: session_id,
      occurred_at: occurred_at,
      event_metadata: event_metadata,
    )
  end
end
