require 'rails_helper'

RSpec.describe Redirect::ContactController do
  before do
    stub_analytics
  end

  subject(:response) { get :show, params: }

  describe '#show' do
    let(:params) { { flow: 'flow', step: 'step', location: 'location', foo: 'bar' } }

    it 'redirects to contact page' do
      redirect_url = MarketingSite.contact_url

      expect(response).to redirect_to redirect_url
      expect(@analytics).to have_logged_event(
        'Contact Page Redirect',
        flow: 'flow',
        location: 'location',
        redirect_url:,
        step: 'step',
      )
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

      let(:redirect_url_base) { MarketingSite.contact_url }
      let(:added_query_params) { '' }
      let(:redirect_url) { redirect_url_base + added_query_params }

      before do
        allow(controller).to receive(:current_sp).and_return(service_provider)
      end

      it 'redirects to the contact page without query params' do
        expect(response).to redirect_to(redirect_url)
        expect(@analytics).to have_logged_event(
          'Contact Page Redirect',
          flow: 'flow',
          location: 'location',
          redirect_url:,
          step: 'step',
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

        it 'redirects to the contact page with query param for agency' do
          expect(response).to redirect_to(redirect_url)
          expect(@analytics).to have_logged_event(
            'Contact Page Redirect',
            flow: 'flow',
            location: 'location',
            redirect_url: redirect_url_base,
            step: 'step',
          )
        end
      end

      context 'with agency and integration' do
        let(:agency) { create(:agency, name: 'Test Agency') }
        let!(:integration) do
          create(:integration, service_provider: service_provider, name: 'Test Integration')
        end
        let(:added_query_params) { '?partner=Test%20Agency&partner_div=Test%20Integration' }

        it 'redirects to the contact page with query params for agency and integration' do
          expect(response).to redirect_to(redirect_url)
          expect(@analytics).to have_logged_event(
            'Contact Page Redirect',
            flow: 'flow',
            location: 'location',
            redirect_url: redirect_url_base,
            step: 'step',
          )
        end
      end
    end
  end
end
