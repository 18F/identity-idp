require 'rails_helper'

RSpec.describe Redirect::ContactController do
  subject(:action) { get :show, params: params }

  let(:base_redirect_url) { MarketingSite.contact_url }
  let(:params) do
    { flow: 'flow', step: 'step', location: 'location', foo: 'bar' }
  end

  before { stub_analytics }

  shared_examples 'redirects to contact page and logs event' do |query_params = ''|
    let(:redirect_url) { "#{base_redirect_url}#{query_params}" }

    it 'redirects to the contact page and logs event' do
      expect(action).to redirect_to(redirect_url)
      expect(@analytics).to have_logged_event(
        'Contact Page Redirect',
        flow: 'flow',
        location: 'location',
        redirect_url: base_redirect_url,
        step: 'step',
      )
    end
  end

  describe '#show' do
    it_behaves_like 'redirects to contact page and logs event'

    context 'with service provider' do
      let(:agency) { nil }
      let(:service_provider) do
        create(
          :service_provider,
          issuer: 'urn:gov:gsa:openidconnect:sp:test_sp',
          agency: agency,
        )
      end

      before do
        allow(controller).to receive(:current_sp).and_return(service_provider)
      end

      it_behaves_like 'redirects to contact page and logs event'

      context 'with agency' do
        let(:agency) { create(:agency, name: 'Test Agency') }

        it_behaves_like 'redirects to contact page and logs event', '?agency=Test+Agency'
      end

      context 'with agency and integration' do
        let(:agency) { create(:agency, name: 'Test Agency') }
        let!(:integration) do
          create(:integration, service_provider: service_provider, name: 'Test Integration')
        end

        it_behaves_like 'redirects to contact page and logs event',
                        '?agency=Test+Agency&integration=Test+Integration'
      end
    end
  end
end
