require 'rails_helper'

RSpec.describe AttemptsApi::DelegationContext do
  let(:session) { {} }
  subject(:context) { described_class.from_session(session) }

  let(:event) do
    AttemptsApi::AttemptEvent.new(
      event_type: 'login-email-and-password-auth',
      session_id: 'sp-session-id',
      occurred_at: Time.zone.now,
      event_metadata: {
        user_uuid: 'sp-agency-uuid',
        google_analytics_cookies: { '_ga' => 'GA1.x' },
        email: 'user@example.com',
        user_ip_address: '192.0.2.1',
        success: true,
      },
    )
  end

  before do
    allow(IdentityConfig.store).to receive_messages(
      attempts_api_enabled: true,
      token_exchange_enabled: true,
      token_exchange_attempts_delivery_enabled: true,
    )
  end

  it 'is inactive when nothing has been started' do
    expect(context.present?).to eq(false)
    expect(context.active?).to eq(false)
    expect(context.buffered_events).to eq([])
  end

  it 'is active only while an enrolled candidate or an approved recipient exists' do
    context.start(request_id: 'req-1', sp_issuer: 'sp', candidate_issuers: [])
    expect(context.present?).to eq(true)
    expect(context.active?).to eq(false)

    context.start(request_id: 'req-1', sp_issuer: 'sp', candidate_issuers: ['agency'])
    expect(context.active?).to eq(true)
    expect(context.candidate_issuers).to eq(['agency'])
    expect(context.sp_issuer).to eq('sp')
    expect(context.request_id).to eq('req-1')
  end

  it 'is inactive while delivery to agencies is switched off' do
    context.start(request_id: 'req-1', sp_issuer: 'sp', candidate_issuers: ['agency'])
    allow(IdentityConfig.store).to receive(:token_exchange_attempts_delivery_enabled)
      .and_return(false)

    expect(context.present?).to eq(true)
    expect(context.active?).to eq(false)
  end

  it 'buffers events as plain data without the SP identifier or GA cookies' do
    context.start(request_id: 'req-1', sp_issuer: 'sp', candidate_issuers: ['agency'])
    context.push_buffered_event(event)

    raw = session[described_class::BUFFER_KEY]
    expect(raw.length).to eq(1)
    expect(raw.first['event_metadata']).to include('email' => 'user@example.com')
    expect(raw.first['event_metadata']).not_to have_key('user_uuid')
    expect(raw.first['event_metadata']).not_to have_key('google_analytics_cookies')

    restored = context.buffered_events.first
    expect(restored.jti).to eq(event.jti)
    expect(restored.event_type).to eq('login-email-and-password-auth')
    expect(restored.session_id).to eq('sp-session-id')
    expect(restored.occurred_at.to_f).to be_within(0.001).of(event.occurred_at.to_f)
    expect(restored.event_metadata).to include(email: 'user@example.com', success: true)
    expect(restored.event_metadata).not_to have_key(:user_uuid)
    expect(restored.event_metadata).not_to have_key(:google_analytics_cookies)
  end

  it 'is carried in the KMS-encrypted part of the session and survives a save' do
    expect(SessionEncryptor::SENSITIVE_PATHS).to include([described_class::BUFFER_KEY])

    context.start(request_id: 'req-1', sp_issuer: 'sp', candidate_issuers: ['agency'])
    context.push_buffered_event(event)
    encryptor = SessionEncryptor.new

    dumped = encryptor.dump(session.deep_dup)
    restored = described_class.from_session(encryptor.load(dumped)).buffered_events.first

    expect(restored.jti).to eq(event.jti)
    expect(restored.occurred_at.to_f).to be_within(0.001).of(event.occurred_at.to_f)
    expect(restored.event_metadata).to include(email: 'user@example.com', success: true)
  end

  it 'keeps the earliest events once the buffer is full' do
    stub_const("#{described_class}::MAX_BUFFERED_EVENTS", 2)
    3.times { context.push_buffered_event(event) }

    expect(context.buffered_event_count).to eq(2)
  end

  it 'tracks approvals, releases and buffer deliveries' do
    context.start(request_id: 'req-1', sp_issuer: 'sp', candidate_issuers: %w[a b])
    context.approve(issuer: 'a', delegation_id: 'dlg_1', agency_uuid: 'uuid-a')
    expect(context.approved_issuers).to eq(['a'])
    expect(context.approved['a']).to eq('delegation_id' => 'dlg_1', 'agency_uuid' => 'uuid-a')

    expect(context.released_for?('req-1')).to eq(false)
    context.mark_released('req-1')
    expect(context.released_for?('req-1')).to eq(true)
    expect(context.released_for?(nil)).to eq(false)

    context.mark_buffer_delivered('a')
    expect(context.buffer_delivered_to?('a')).to eq(true)
    expect(context.buffer_delivered_to?('b')).to eq(false)
  end

  it 'keeps earlier approvals when a new request starts in the same session' do
    context.start(request_id: 'req-1', sp_issuer: 'sp', candidate_issuers: ['a'])
    context.approve(issuer: 'a', delegation_id: 'dlg_1', agency_uuid: 'uuid-a')
    context.start(request_id: 'req-2', sp_issuer: 'sp', candidate_issuers: ['b'])
    expect(context.approved_issuers).to eq(['a'])
    expect(context.candidate_issuers).to eq(['b'])
    expect(context.request_id).to eq('req-2')
  end

  it 'clears everything' do
    context.start(request_id: 'req-1', sp_issuer: 'sp', candidate_issuers: ['a'])
    context.push_buffered_event(event)
    context.clear
    expect(session).to eq({})
  end

  it 'is a no-op with no session' do
    context = described_class.from_session(nil)
    expect(context.active?).to eq(false)
    expect { context.push_buffered_event(event) }.not_to raise_error
    expect(context.buffered_events).to eq([])
  end
end
