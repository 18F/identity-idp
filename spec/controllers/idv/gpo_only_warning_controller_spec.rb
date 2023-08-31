require 'rails_helper'

RSpec.describe Idv::GpoOnlyWarningController do
  include IdvHelper

  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
    stub_analytics
    subject.user_session['idv/doc_auth'] = {}
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: Mail only warning visited' }
    let(:analytics_args) do
      { analytics_id: 'Doc Auth' }
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'sends analytics_visited event' do
      get :show

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    context 'flow_session is nil' do
      it 'renders the show template and initializes flow session' do
        subject.user_session.delete('idv/doc_auth')

        get :show

        expect(response).to render_template :show
        expect(subject.user_session['idv/doc_auth'][:skip_vendor_outage]).to eq(true)
      end
    end
  end

  context 'page links' do
    render_views
    context 'exit url' do
      let(:sp) { create(:service_provider, issuer: 'urn:gov:gsa:openidconnect:sp:test_cookie') }

      context 'with current sp' do
        it 'links to return_to_sp_url' do
          allow(controller).to receive(:current_sp).and_return(sp)
          get :show
          expect(response.body).to include(sp.return_to_sp_url)
        end
      end

      context 'without current sp' do
        it 'links to account_path' do
          allow(controller).to receive(:current_sp).and_return(nil)
          get :show
          expect(response.body).to include(account_path)
        end
      end
    end
  end
end
