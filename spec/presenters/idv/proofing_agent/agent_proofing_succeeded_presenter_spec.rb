require 'rails_helper'

RSpec.describe Idv::ProofingAgent::AgentProofingSucceededPresenter do
  include Rails.application.routes.url_helpers

  around { |ex| Time.use_zone('UTC') { ex.run } }

  subject(:presenter) do
    described_class.new(
      verified_at: '2026-04-02 16:24:00 -0500',
      url_options: { host: 'example.com' },
    )
  end

  describe '#confirmation_url' do
    it 'routes users to the sign-in screen' do
      expect(presenter.confirmation_url).to eq(new_user_session_url(host: 'example.com'))
    end
  end

  describe '#contact_us_url' do
    it 'returns the marketing site contact url' do
      expect(presenter.contact_us_url).to eq(MarketingSite.contact_url)
    end
  end

  describe '#change_password_url' do
    it 'links to the devise edit-password route' do
      expect(presenter.change_password_url).to include('users/password/edit')
    end
  end

  describe '#verified_at' do
    it 'returns a Time in American Samoa zone (UTC-11)' do
      expect(presenter.verified_at.utc_offset).to eq(-11 * 60 * 60)
    end
  end

  describe '#deadline' do
    context 'with the ticket worked example (4:24pm CT April 2)' do
      it 'returns April 4, 2026 per ticket spec' do
        expect(presenter.deadline.to_date).to eq(Date.new(2026, 4, 4))
      end

      it 'returns end of day in American Samoa time' do
        expect(presenter.deadline.utc_offset).to eq(-11 * 60 * 60)
        expect(presenter.deadline.strftime('%H:%M:%S')).to eq('23:59:59')
      end
    end

    context 'when verified just past midnight Eastern (12:30am ET April 3)' do
      subject(:presenter) do
        described_class.new(
          verified_at: '2026-04-03 00:30:00 -0500',
          url_options: { host: 'example.com' },
        )
      end

      it 'returns April 4, 2026 (Samoa still on April 2 at that moment)' do
        expect(presenter.deadline.to_date).to eq(Date.new(2026, 4, 4))
      end
    end

    context 'when verified in the morning in Guam (9am April 1, UTC+10)' do
      subject(:presenter) do
        described_class.new(
          verified_at: '2026-04-01 09:00:00 +1000',
          url_options: { host: 'example.com' },
        )
      end

      it 'returns April 2, 2026 (Samoa still on March 31 at that moment)' do
        expect(presenter.deadline.to_date).to eq(Date.new(2026, 4, 2))
      end
    end

    context 'when verified in the afternoon in Hawaii (5pm April 2, UTC-10)' do
      subject(:presenter) do
        described_class.new(
          verified_at: '2026-04-02 17:00:00 -1000',
          url_options: { host: 'example.com' },
        )
      end

      it 'returns April 4, 2026' do
        expect(presenter.deadline.to_date).to eq(Date.new(2026, 4, 4))
      end
    end

    context 'when verified in the evening Pacific Time (10pm PT April 2, UTC-7)' do
      subject(:presenter) do
        described_class.new(
          verified_at: '2026-04-02 22:00:00 -0700',
          url_options: { host: 'example.com' },
        )
      end

      it 'returns April 4, 2026' do
        expect(presenter.deadline.to_date).to eq(Date.new(2026, 4, 4))
      end
    end

    context 'when verified in American Samoa local time (UTC-11)' do
      subject(:presenter) do
        described_class.new(
          verified_at: '2026-04-02 10:00:00 -1100',
          url_options: { host: 'example.com' },
        )
      end

      it 'returns April 4, 2026 (no zone shift needed)' do
        expect(presenter.deadline.to_date).to eq(Date.new(2026, 4, 4))
      end
    end
  end
end
