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

  before do
    allow(IdentityConfig.store).to receive(:idv_account_verified_email_campaign_id)
      .and_return('20241030')
  end

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

    describe '#displayed_sign_in_url' do
      it 'links to ourselves since there is no SP' do
        expect(presenter.displayed_sign_in_url).to eq(root_url)
      end
    end

    describe '#sign_in_url' do
      let(:params) do
        uri = URI.parse(presenter.sign_in_url)
        Rack::Utils.parse_query(uri.query).with_indifferent_access
      end

      it 'has no issuer' do
        expect(params[:issuer]).to be_nil
      end

      it 'has the correct campaign ID' do
        expect(params[:campaign_id]).to eq('20241030')
      end
    end
  end

  context 'where there is a service provider' do
    context 'when the service provider has no post-IdV follow-up URL' do
      let(:service_provider) do
        create(
          :service_provider,
          issuer: 'urn:my:awesome:sp',
          post_idv_follow_up_url: nil,
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

      describe '#bare_sign_in_url' do
        it 'links to ourselves' do
          expect(presenter.displayed_sign_in_url).to eq(root_url)
        end
      end

      describe '#sign_in_url' do
        let(:params) do
          uri = URI.parse(presenter.sign_in_url)
          Rack::Utils.parse_query(uri.query).with_indifferent_access
        end

        it 'has the correct issuer' do
          expect(params[:issuer]).to eq('urn:my:awesome:sp')
        end

        it 'has the correct campaign ID' do
          expect(params[:campaign_id]).to eq('20241030')
        end
      end
    end

    context 'when the service provider does have a post-IdV follow-up URL' do
      let(:service_provider) do
        create(
          :service_provider,
          issuer: 'urn:my:awesome:sp',
          post_idv_follow_up_url: 'https://www.mysp.com',
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

      describe '#bare_sign_in_url' do
        it 'links to the SP' do
          expect(presenter.displayed_sign_in_url).to eq('https://www.mysp.com')
        end
      end

      describe '#sign_in_url' do
        let(:params) do
          uri = URI.parse(presenter.sign_in_url)
          Rack::Utils.parse_query(uri.query).with_indifferent_access
        end

        it 'has the correct issuer' do
          expect(params[:issuer]).to eq('urn:my:awesome:sp')
        end

        it 'has the correct campaign ID' do
          expect(params[:campaign_id]).to eq('20241030')
        end
      end
    end
  end
end
