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
        expect(response).to redirect_to root_url
        expect(@analytics).not_to have_logged_event('External Redirect')
      end
    end

    context 'with invalid help center article' do
      let(:params) { super().merge(category: 'foo', article: 'bar') }

      it 'redirects to the root url' do
        expect(response).to redirect_to root_url
        expect(@analytics).not_to have_logged_event('External Redirect')
      end
    end

    context 'with valid help center article' do
      let(:category) { 'verify-your-identity' }
      let(:article) { 'accepted-state-issued-identification' }
      let(:params) { super().merge(category:, article:) }

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
  end
end
