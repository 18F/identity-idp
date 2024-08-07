require 'rails_helper'

RSpec.describe Redirect::PolicyController do
  before do
    stub_analytics
  end

  describe '#show' do
    let(:location_params) { { flow: 'flow', step: 'step', location: 'location', foo: 'bar' } }

    it 'redirects to security and privacy practices policy page' do
      redirect_url = MarketingSite.security_and_privacy_practices_url

      get :show, params: location_params

      expect(response).to redirect_to redirect_url
      expect(@analytics).to have_logged_event(
        'Policy Page Redirect',
        flow: 'flow',
        location: 'location',
        redirect_url: redirect_url,
        step: 'step',
      )
    end

    context 'with security_and_privacy_practices policy parameter' do
      let(:params) { location_params.merge(policy: :security_and_privacy_practices) }

      it 'redirects to security and privacy practices policy page' do
        redirect_url = MarketingSite.security_and_privacy_practices_url

        get :show, params: location_params

        expect(response).to redirect_to redirect_url
        expect(@analytics).to have_logged_event(
          'Policy Page Redirect',
          flow: 'flow',
          location: 'location',
          redirect_url: redirect_url,
          step: 'step',
        )
      end
    end

    context 'with privacy_act_statement policy parameter' do
      let(:params) { location_params.merge(policy: :privacy_act_statement) }

      it 'redirects to privacy act statement policy page' do
        redirect_url = MarketingSite.privacy_act_statement_url

        get :show, params: params

        expect(response).to redirect_to redirect_url
        expect(@analytics).to have_logged_event(
          'Policy Page Redirect',
          flow: 'flow',
          location: 'location',
          redirect_url: redirect_url,
          step: 'step',
        )
      end
    end
  end
end
