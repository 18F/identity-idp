require 'rails_helper'

RSpec.describe Redirect::HelpCenterController do
  subject(:response) { get :show, params: params }

  let(:params) { {} }

  before { stub_analytics }

  shared_examples 'redirects to help center article and logs' do
    it 'redirects to the help center article and logs' do
      expect(response).to redirect_to redirect_url
      expect(@analytics).to have_logged_event(
        'External Redirect',
        redirect_url: redirect_url_base,
      )
    end
  end

  describe '#show' do
    let(:category) { 'verify-your-identity' }
    let(:article) { 'accepted-identification-documents' }

    context 'without help center article' do
      it 'redirects to the root url' do
        expect(response).to redirect_to MarketingSite.help_url
        expect(@analytics).to have_logged_event('External Redirect')
      end
    end

    context 'with invalid help center article' do
      let(:params) { { category: category, article: 'invalid' } }

      it 'redirects to the root url' do
        expect(response).to redirect_to MarketingSite.help_url
        expect(@analytics).to have_logged_event('External Redirect')
      end
    end

    context 'with valid help center article' do
      let(:category) { 'verify-your-identity' }
      let(:article) { 'accepted-identification-documents' }
      let(:params) { super().merge(category:, article:) }

      it 'redirects to the help center article and logs' do
        redirect_url = MarketingSite.help_center_article_url(category:, article:)
        expect(response).to redirect_to redirect_url
        expect(@analytics).to have_logged_event('External Redirect', redirect_url:)
      end

      context 'with optional anchor' do
        let(:article_anchor) { 'heading' }
        let(:params) { super().merge(article_anchor: article_anchor) }
        let(:redirect_url) do
          MarketingSite.help_center_article_url(category:, article:, article_anchor:)
        end
        let(:redirect_url_base) { redirect_url }

        it_behaves_like 'redirects to help center article and logs'
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

      it_behaves_like 'redirects to help center article and logs'

      context 'with agency' do
        let(:agency) { create(:agency, name: 'Test Agency') }
        let(:added_query_params) { '?agency=Test+Agency' }

        it_behaves_like 'redirects to help center article and logs'
      end

      context 'with agency and integration' do
        let(:agency) { create(:agency, name: 'Test Agency') }
        let!(:integration) do
          create(:integration, service_provider: service_provider, name: 'Test Integration')
        end
        let(:added_query_params) { '?agency=Test+Agency&integration=Test+Integration' }

        it_behaves_like 'redirects to help center article and logs'
      end
    end
  end
end
