require 'rails_helper'

shared_examples_for 'an idv session errors controller action' do
  context 'the user is authenticated and has not confirmed their profile' do
    it 'renders the error' do
      stub_sign_in

      get action

      expect(response).to render_template(template)
    end
  end

  context 'the user is authenticated and has confirmed their profile' do
    let(:idv_session_profile_confirmation) { true }

    it 'redirects to the phone url' do
      stub_sign_in

      get action

      expect(response).to redirect_to(idv_phone_url)
    end
  end

  context 'the user is not authenticated and recovering their account' do
    it 'renders the error' do
      user = create(:user, :signed_up)
      controller.session[:ial2_recovery_user_id] = user.id

      get action

      expect(response).to render_template(template)
    end
  end

  context 'the user is not authenticated and in doc capture flow' do
    it 'renders the error' do
      user = create(:user, :signed_up)
      controller.session[:doc_capture_user_id] = user.id

      get action

      expect(response).to render_template(template)
    end
  end

  context 'the user is not authenticated and not recovering their account' do
    it 'redirects to sign in' do
      get action

      expect(response).to redirect_to(new_user_session_url)
    end
  end
end

describe Idv::SessionErrorsController do
  let(:idv_session) { double }
  let(:idv_session_profile_confirmation) { false }

  before do
    allow(idv_session).to receive(:profile_confirmation).
      and_return(idv_session_profile_confirmation)
    allow(controller).to receive(:idv_session).and_return(idv_session)
  end

  describe 'before_actions' do
    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:sp_context_needed?)
    end
  end

  describe '#warning' do
    let(:action) { :warning }
    let(:template) { 'idv/session_errors/warning' }

    it_behaves_like 'an idv session errors controller action'
  end

  describe '#failure' do
    let(:action) { :failure }
    let(:template) { 'idv/session_errors/failure' }

    it_behaves_like 'an idv session errors controller action'
  end
end
