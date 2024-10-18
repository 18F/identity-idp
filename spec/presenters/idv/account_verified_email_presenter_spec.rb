require 'rails_helper'

RSpec.describe Idv::AccountVerifiedEmailPresenter do
  include Rails.application.routes.url_helpers

  let(:service_provider) { create(:service_provider) }

  let(:profile) do
    create(
      :profile,
      initiating_service_provider: service_provider,
    )
  end

  subject(:presenter) { described_class.new(profile:, url_options: {}) }

  context 'when there is no associated service provider' do
    let(:service_provider) { nil }

    describe '#show_cta?' do
      it 'is true' do
        expect(presenter.show_cta?).to eq(true)
      end
    end

    describe '#sp_name' do
      it 'returns our APP_NAME instead' do
        expect(presenter.sp_name).to eq(APP_NAME)
      end
    end

    describe '#sign_in_url' do
      it 'links to ourselves since there is no SP' do
        expect(presenter.sign_in_url).to eq(root_url)
      end
    end
  end

  context 'where there is a service provider' do
    context 'when the service provider has no return URL' do
      let(:service_provider) do
        create(
          :service_provider,
          return_to_sp_url: nil,
          friendly_name: 'My Awesome SP',
        )
      end

      describe '#show_cta?' do
        it 'is false' do
          expect(presenter.show_cta?).to eq(false)
        end
      end

      describe '#sp_name' do
        it 'returns the SP name' do
          expect(presenter.sp_name).to eq('My Awesome SP')
        end
      end

      describe '#sign_in_url' do
        it 'links to ourselves' do
          expect(presenter.sign_in_url).to eq(root_url)
        end
      end
    end

    context 'when the service provider does have a return URL' do
      let(:service_provider) do
        create(
          :service_provider,
          return_to_sp_url: 'https://www.example.com',
          friendly_name: 'My Awesome SP',
        )
      end

      describe '#show_cta?' do
        it 'is true' do
          expect(presenter.show_cta?).to eq(true)
        end
      end

      describe '#sp_name' do
        it 'shows the SP name' do
          expect(presenter.sp_name).to eq('My Awesome SP')
        end
      end

      describe '#sign_in_url' do
        it 'links to the SP' do
          expect(presenter.sign_in_url).to eq('https://www.example.com')
        end
      end
    end
  end
end
