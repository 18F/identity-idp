require 'rails_helper'

RSpec.describe Idv::ProofingAgent::AgentProofingFailurePresenter do
  let(:visited_at) { '2026-03-18T12:00:00-04:00' }
  let(:url_options) { { host: 'idp.example.com' } }
  let(:presenter) do
    described_class.new(visited_at: visited_at, url_options: url_options)
  end

  describe '#visited_at' do
    it 'returns the parsed timestamp when a string is provided' do
      expect(presenter.visited_at).to eq(Time.zone.parse(visited_at))
    end

    context 'when a Time object is provided' do
      let(:visited_at) { Time.zone.now }

      it 'returns the Time object directly' do
        expect(presenter.visited_at).to eq(visited_at)
      end
    end
  end

  describe '#help_center_url' do
    it 'returns the marketing site help URL' do
      expect(presenter.help_center_url).to eq(MarketingSite.help_url)
    end
  end

  describe '#contact_us_url' do
    it 'returns the marketing site contact URL' do
      expect(presenter.contact_us_url).to eq(MarketingSite.contact_url)
    end
  end

  describe '#change_password_url' do
    it 'returns the edit user password URL' do
      expect(presenter.change_password_url)
        .to eq(Rails.application.routes.url_helpers.edit_user_password_url(url_options))
    end
  end
end
