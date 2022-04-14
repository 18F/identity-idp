require 'rails_helper'

describe Redirect::HelpCenterController do
  before do
    stub_analytics
  end

  let(:category) { nil }
  let(:article) { nil }
  let(:location_params) { {} }
  subject(:response) do
    get :show, params: { category: category, article: article, **location_params }
  end

  describe '#show' do
    context 'without help center article' do
      it 'redirects to the root url' do
        expect(response).to redirect_to root_url
        expect(@analytics).not_to have_logged_event('External Redirect')
      end
    end

    context 'with invalid help center article' do
      let(:category) { 'foo' }
      let(:article) { 'bar' }

      it 'redirects to the root url' do
        expect(response).to redirect_to root_url
        expect(@analytics).not_to have_logged_event('External Redirect')
      end
    end

    context 'with valid help center article' do
      let(:category) { 'verify-your-identity' }
      let(:article) { 'accepted-state-issued-identification' }

      it 'redirects to the help center article and logs' do
        redirect_url = MarketingSite.help_center_article_url(
          category: 'verify-your-identity',
          article: 'accepted-state-issued-identification',
        )
        expect(response).to redirect_to redirect_url
        expect(@analytics).to have_logged_event(
          'External Redirect',
          redirect_url: redirect_url,
        )
      end

      context 'with location params' do
        let(:location_params) { { flow: 'flow', step: 'step', location: 'location', foo: 'bar' } }

        it 'logs with location params' do
          response

          expect(@analytics).to have_logged_event(
            'External Redirect',
            redirect_url: MarketingSite.help_center_article_url(
              category: 'verify-your-identity',
              article: 'accepted-state-issued-identification',
            ),
            flow: 'flow',
            step: 'step',
            location: 'location',
          )
        end
      end
    end
  end
end
