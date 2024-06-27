require 'rails_helper'

RSpec.describe Redirect::HelpCenterController do
  before do
    stub_analytics
  end

  let(:params) { {} }
  subject(:response) { get :show, params: }

  describe '#show' do
    context 'without help center article' do
      it 'redirects to the root url' do
        expect(response).to redirect_to MarketingSite.help_url
        expect(@analytics).to have_logged_event('External Redirect')
      end
    end

    context 'with invalid help center article' do
      let(:params) { { category: 'foo', article: 'bar' } }

      it 'redirects to the root url' do
        expect(response).to redirect_to MarketingSite.help_url
        expect(@analytics).to have_logged_event('External Redirect')
      end
    end

    context 'with valid help center article' do
      let(:category) { 'verify-your-identity' }
      let(:article) { 'accepted-state-issued-identification' }
      let(:params) { { category:, article: } }

      it 'redirects to the help center article and logs' do
        redirect_url = MarketingSite.help_center_article_url(category:, article:)
        expect(response).to redirect_to redirect_url
        expect(@analytics).to have_logged_event(
          'External Redirect',
          hash_including(redirect_url: redirect_url),
        )
      end

      context 'with optional anchor' do
        let(:article_anchor) { 'heading' }
        let(:params) { super().merge(article_anchor:) }

        it 'redirects to the help center article and logs' do
          redirect_url = MarketingSite.help_center_article_url(category:, article:, article_anchor:)
          expect(response).to redirect_to redirect_url
          expect(@analytics).to have_logged_event(
            'External Redirect',
            hash_including(redirect_url: redirect_url),
          )
        end
      end

      context 'with location params' do
        let(:flow) { 'flow' }
        let(:step) { 'step' }
        let(:location) { 'location' }
        let(:params) { super().merge(flow:, step:, location:, foo: 'bar') }

        it 'logs with location params' do
          response

          expect(@analytics).to have_logged_event(
            'External Redirect',
            redirect_url: MarketingSite.help_center_article_url(category:, article:),
            flow:,
            step:,
            location:,
          )
        end
      end
    end

    context 'with service provider' do
      let(:category) { 'verify-your-identity' }
      let(:article) { 'accepted-state-issued-identification' }
      let(:agency) { nil }
      let!(:service_provider) do
        create(
          :service_provider,
          issuer: 'urn:gov:gsa:openidconnect:sp:test_sp',
          agency: agency,
        )
      end
      let(:params) { { category:, article: } }
      let(:redirect_url_base) do
        MarketingSite.help_center_article_url(
          category:, article:,
        )
      end
      let(:added_query_params) { '' }
      let(:redirect_url) { redirect_url_base + added_query_params }

      before do
        allow(controller).to receive(:current_sp).and_return(service_provider)
      end

      it 'redirects to the help center article and logs' do
        expect(response).to redirect_to(redirect_url)
        expect(@analytics).to have_logged_event(
          'External Redirect',
          hash_including(redirect_url: redirect_url_base),
        )
      end

      context 'with agency' do
        let(:agency) { create(:agency, name: 'Test Agency') }
        let!(:service_provider) do
          create(
            :service_provider,
            issuer: 'urn:gov:gsa:openidconnect:sp:test_sp',
            agency: agency,
          )
        end
        let(:added_query_params) { '?partner=Test%20Agency' }

        it 'redirects to the help center article and logs' do
          expect(response).to redirect_to(redirect_url)
          expect(@analytics).to have_logged_event(
            'External Redirect',
            hash_including(redirect_url: redirect_url_base),
          )
        end
      end

      context 'with agency and integration' do
        let(:agency) { create(:agency, name: 'Test Agency') }
        let!(:integration) do
          create(:integration, service_provider: service_provider, name: 'Test Integration')
        end
        let(:added_query_params) { '?partner=Test%20Agency&partner_div=Test%20Integration' }

        it 'redirects to the help center article and logs' do
          expect(response).to redirect_to(redirect_url)
          expect(@analytics).to have_logged_event(
            'External Redirect',
            hash_including(redirect_url: redirect_url_base),
          )
        end
      end
    end
  end
end
