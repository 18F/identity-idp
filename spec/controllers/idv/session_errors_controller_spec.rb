require 'rails_helper'

shared_examples_for 'an idv session errors controller action' do
  context 'the user is authenticated and has not confirmed their profile' do
    let(:user) { build(:user) }

    it 'renders the error' do
      get action

      expect(response).to render_template(template)
    end
  end

  context 'the user is authenticated and has confirmed their profile' do
    let(:idv_session_profile_confirmation) { true }
    let(:user) { build(:user) }

    it 'redirects to the phone url' do
      get action

      expect(response).to redirect_to(idv_phone_url)
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
  let(:user) { nil }

  before do
    allow(idv_session).to receive(:profile_confirmation).
      and_return(idv_session_profile_confirmation)
    allow(controller).to receive(:idv_session).and_return(idv_session)
    stub_sign_in(user) if user
  end

  describe 'before_actions' do
    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  describe '#exception' do
    let(:action) { :exception }
    let(:template) { 'idv/session_errors/exception' }
    let(:params) { {} }

    subject(:response) { get action, params: params }

    it_behaves_like 'an idv session errors controller action'
  end

  describe '#warning' do
    let(:action) { :warning }
    let(:template) { 'idv/session_errors/warning' }
    let(:params) { {} }

    subject(:response) { get :warning, params: params }

    it_behaves_like 'an idv session errors controller action'

    context 'with throttle attempts' do
      let(:user) { create(:user) }

      before do
        Throttle.new(throttle_type: :proof_address, user: user).increment!
      end

      it 'assigns remaining count' do
        response

        expect(assigns(:remaining_attempts)).to be_kind_of(Numeric)
      end

      it 'assigns URL to try again' do
        response

        expect(assigns(:try_again_path)).to eq(idv_doc_auth_path)
      end

      context 'in in-person proofing flow' do
        let(:params) { { flow: 'in_person' } }

        it 'assigns URL to try again' do
          response

          expect(assigns(:try_again_path)).to eq(idv_in_person_path)
        end
      end
    end
  end

  describe '#failure' do
    let(:action) { :failure }
    let(:template) { 'idv/session_errors/failure' }

    it_behaves_like 'an idv session errors controller action'

    context 'while throttled' do
      let(:user) { create(:user) }

      before do
        Throttle.new(throttle_type: :proof_address, user: user).increment_to_throttled!
      end

      it 'assigns expiration time' do
        get action

        expect(assigns(:expires_at)).to be_kind_of(Time)
      end
    end
  end

  describe '#ssn_failure' do
    let(:action) { :ssn_failure }
    let(:template) { 'idv/session_errors/failure' }

    it_behaves_like 'an idv session errors controller action'

    context 'while throttled' do
      let(:user) { build(:user) }
      let(:ssn) { '666666666' }

      around do |ex|
        freeze_time { ex.run }
      end

      before do
        Throttle.new(
          throttle_type: :proof_ssn,
          target: Pii::Fingerprinter.fingerprint(ssn),
        ).increment_to_throttled!
        controller.user_session['idv/doc_auth'] = { 'pii_from_doc' => { 'ssn' => ssn } }
      end

      it 'assigns expiration time' do
        get action

        expect(assigns(:expires_at)).not_to eq(Time.zone.now)
      end
    end
  end

  describe '#throttled' do
    let(:action) { :throttled }
    let(:template) { 'idv/session_errors/throttled' }

    it_behaves_like 'an idv session errors controller action'

    context 'while throttled' do
      let(:user) { create(:user) }

      before do
        Throttle.new(throttle_type: :idv_doc_auth, user: user).increment_to_throttled!
      end

      it 'assigns expiration time' do
        get action

        expect(assigns(:expires_at)).to be_kind_of(Time)
      end
    end
  end
end
