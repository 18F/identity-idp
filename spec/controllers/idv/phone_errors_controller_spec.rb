require 'rails_helper'

shared_examples_for 'an idv phone errors controller action' do
  describe 'before_actions' do
    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  context 'the user is authenticated and has not confirmed their phone' do
    it 'renders the error' do
      stub_sign_in

      get action

      expect(response).to render_template(template)
    end
  end

  context 'the user is authenticated and has confirmed their phone' do
    let(:idv_session_user_phone_confirmation) { true }

    it 'redirects to the review url' do
      stub_sign_in

      get action

      expect(response).to redirect_to(idv_review_url)
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

  context 'the user is not authenticated and not recovering their account' do
    it 'redirects to sign in' do
      get action

      expect(response).to redirect_to(new_user_session_url)
    end
  end
end

describe Idv::PhoneErrorsController do
  let(:idv_session) { double }
  let(:idv_session_user_phone_confirmation) { false }

  before do
    allow(idv_session).to receive(:user_phone_confirmation).
      and_return(idv_session_user_phone_confirmation)
    allow(idv_session).to receive(:step_attempts).and_return(phone: 1)
    allow(controller).to receive(:idv_session).and_return(idv_session)
  end

  describe '#warning' do
    let(:action) { :warning }
    let(:template) { 'idv/phone_errors/warning' }

    it_behaves_like 'an idv phone errors controller action'
  end

  describe '#timeout' do
    let(:action) { :timeout }
    let(:template) { 'idv/phone_errors/timeout' }

    it_behaves_like 'an idv phone errors controller action'
  end

  describe '#jobfail' do
    let(:action) { :jobfail }
    let(:template) { 'idv/phone_errors/jobfail' }

    it_behaves_like 'an idv phone errors controller action'
  end

  describe '#failure' do
    let(:action) { :failure }
    let(:template) { 'idv/phone_errors/failure' }

    it_behaves_like 'an idv phone errors controller action'
  end
end
