require 'rails_helper'

RSpec.describe SpHandoffBouncer do
  let(:sp_session) { {} }
  let(:now) { Time.zone.now }
  subject(:bouncer) { SpHandoffBouncer.new(sp_session) }

  describe '#add_handoff_time!' do
    it 'sets the handoff time in the session' do
      expect { bouncer.add_handoff_time!(now) }
        .to(change { sp_session[:sp_handoff_start_time] }.to(now))
    end
  end

  describe '#bounced?' do
    subject(:bounced?) { bouncer.bounced? }

    context 'with no handoff start time in the session' do
      it { expect(bounced?).to eq(false) }
    end

    context 'with a handoff time (as a string) in the session that is within the bounce window' do
      before do
        bouncer.add_handoff_time!(
          (now + 1 - IdentityConfig.store.sp_handoff_bounce_max_seconds.seconds).to_s,
        )
      end

      it { expect(bounced?).to eq(true) }
    end

    context 'with a handoff time (as a time) in the session that is within the bounce window' do
      before do
        bouncer.add_handoff_time!(
          now + 1 - IdentityConfig.store.sp_handoff_bounce_max_seconds.seconds,
        )
      end

      it { expect(bounced?).to eq(true) }
    end

    context 'with a handoff time (as a string) in the session that older than the bounce window' do
      before do
        bouncer.add_handoff_time!(
          (now - 1 - IdentityConfig.store.sp_handoff_bounce_max_seconds.seconds).to_s,
        )
      end

      it { expect(bounced?).to eq(false) }
    end
  end
end
