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
end
