require 'rails_helper'

RSpec.describe Idv::GpoOnlyWarningController do
  include IdvHelper

  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
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
    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    context 'flow_session is nil' do
      it 'sends analytics_visited event' do
        subject.user_session.delete('idv/doc_auth')

        get :show

        expect(response).to render_template :show
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

    context 'welcome url' do
      context 'welcome controller is enabled' do
        it 'links to idv_welcome_url' do
          allow(IdentityConfig.store).to receive(:doc_auth_welcome_controller_enabled).
            and_return(true)
          get :show
          expect(response.body).to include(idv_welcome_url)
        end
      end

      context 'welcome controller is not enabled' do
        it 'links to FSM welcome step' do
          allow(IdentityConfig.store).to receive(:doc_auth_welcome_controller_enabled).
            and_return(false)
          get :show
          expect(response.body).to include(idv_doc_auth_step_path(step: :welcome))
        end
      end
    end
  end
end
