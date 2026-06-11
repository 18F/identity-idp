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
    it 'returns a Time in UTC-5' do
      expect(presenter.verified_at.utc_offset).to eq(-5 * 60 * 60)
    end
  end

  describe '#deadline' do
    let(:correct_deadline) { Date.new(2026, 6, 3) }

    it 'gives the incorrect deadline before 3pm in Pacific/Guam' do
      # rubocop:disable Rails/TimeZoneAssignment
      Time.zone = 'Pacific/Guam'
      # rubocop:enable Rails/TimeZoneAssignment

      verified_at = Time.new(2026, 6, 1, 14, 0, 0, Time.zone).to_s
      presenter = described_class.new(
        verified_at:,
        url_options: { host: 'example.com' },
      )

      expect(presenter.deadline.to_date).to eq(correct_deadline - 1.day)
    end

    it 'gives the correct deadline after 3pm in Pacific/Guam' do
      # rubocop:disable Rails/TimeZoneAssignment
      Time.zone = 'Pacific/Guam'
      # rubocop:enable Rails/TimeZoneAssignment

      verified_at = Time.new(2026, 6, 1, 15, 0, 0, Time.zone).to_s
      presenter = described_class.new(
        verified_at:,
        url_options: { host: 'example.com' },
      )

      expect(presenter.deadline.to_date).to eq(correct_deadline)

      verified_at = Time.new(2026, 6, 1, 23, 59, 59, Time.zone).to_s
      presenter = described_class.new(
        verified_at:,
        url_options: { host: 'example.com' },
      )

      expect(presenter.deadline.to_date).to eq(correct_deadline)
    end

    shared_examples 'gives the correct deadline for the whole business day' do |tz|
      before do
        # rubocop:disable Rails/TimeZoneAssignment
        Time.zone = tz
        # rubocop:enable Rails/TimeZoneAssignment
      end

      it "gives the correct deadline at 8am in #{tz}" do
        verified_at = Time.new(2026, 6, 1, 8, 0, 0, Time.zone).to_s
        presenter = described_class.new(
          verified_at:,
          url_options: { host: 'example.com' },
        )

        expect(presenter.deadline.to_date).to eq(correct_deadline)
      end

      it "gives the correct deadline at 5:59pm in #{tz}" do
        verified_at = Time.new(2026, 6, 1, 17, 59, 59, Time.zone).to_s
        presenter = described_class.new(
          verified_at:,
          url_options: { host: 'example.com' },
        )

        expect(presenter.deadline.to_date).to eq(correct_deadline)
      end
    end

    %w[
      US/Samoa
      US/Hawaii
      US/Alaska
      US/Pacific
      US/Mountain
      US/Central
      US/Eastern
      America/Puerto_Rico
    ].each do |tz|
      it_behaves_like 'gives the correct deadline for the whole business day', tz
    end
  end
end
