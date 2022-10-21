require 'rails_helper'

shared_examples_for 'an inherited proofing errors controller action' do
  context 'when user is not authenticated' do
    it 'redirects to sign in' do
      get :show, params: params

      expect(response).to redirect_to(new_user_session_url)
    end
  end
end

describe Idv::InheritedProofingErrorController do
  let(:idv_session) { double }
  let(:user) { nil }

  before do
    allow(controller).to receive(:idv_session).and_return(idv_session)
    stub_sign_in(user) if user
  end

  context 'failure page' do
    let(:params) { { type: :failure } }

    it_behaves_like 'an inherited proofing errors controller action'

    context 'user is signed in' do
      let(:user) { create(:user) }

      describe '#show' do

        it 'renders the failure page' do
          get :show, params: params

          expect(response).to render_template('idv/inherited_proofing/error/failure')
        end
      end
    end
  end
end

