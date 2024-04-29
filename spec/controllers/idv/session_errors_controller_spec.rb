require 'rails_helper'

RSpec.describe Idv::SessionErrorsController do
  shared_examples_for 'an idv session errors controller action' do
    context 'the user is authenticated and has not confirmed their profile' do
      let(:user) { build(:user) }

      it 'renders the error' do
        get action
        expect(response).to render_template(template)
      end

      it 'logs an event' do
        expect(@analytics).to receive(:track_event).with(
          'IdV: session error visited',
          hash_including(type: action.to_s),
        ).once
        get action
      end

      context 'fetch() request from form-steps-wait JS' do
        before do
          request.headers['X-Form-Steps-Wait'] = '1'
        end

        it 'returns an empty response' do
          get action
          expect(response).to have_http_status(204)
        end
        it 'does not log an event' do
          expect(@analytics).not_to receive(:track_event).
            with('IdV: session error visited', anything)
          get action
        end
      end
    end

    context 'the user is authenticated and has confirmed their profile' do
      let(:verify_info_step_complete) { true }
      let(:user) { build(:user) }

      it 'redirects to the phone url' do
        get action

        expect(response).to redirect_to(idv_phone_url)
      end
      it 'does not log an event' do
        expect(@analytics).not_to receive(:track_event).with(
          'IdV: session error visited',
          hash_including(type: action.to_s),
        )
        get action
      end
    end
  end

  shared_examples_for 'non-authenticated idv session errors controller action' do
    context 'the user is not authenticated and in doc capture flow' do
      before do
        user = create(:user, :fully_registered)
        controller.session[:doc_capture_user_id] = user.id
      end
      it 'renders the error' do
        get action
        expect(response).to render_template(template)
      end
      it 'logs an event' do
        expect(@analytics).to receive(:track_event).with(
          'IdV: session error visited',
          hash_including(type: action.to_s),
        ).once
        get action
      end

      context 'fetch() request from form-steps-wait JS' do
        before do
          request.headers['X-Form-Steps-Wait'] = '1'
        end

        it 'returns an empty response' do
          get action
          expect(response).to have_http_status(204)
        end
        it 'does not log an event' do
          expect(@analytics).not_to receive(:track_event).
            with('IdV: session error visited', anything)
          get action
        end
      end
    end

    context 'the user is not authenticated and not recovering their account' do
      it 'redirects to sign in' do
        get action

        expect(response).to redirect_to(new_user_session_url)
      end
      it 'does not log an event' do
        expect(@analytics).not_to receive(:track_event).with(
          'IdV: session error visited',
          hash_including(type: action.to_s),
        )
        get action
      end
    end

    context 'the user is in the hybrid flow' do
      render_views
      let(:hybrid_user) { create(:user) }

      before do
        session[:doc_capture_user_id] = hybrid_user.id
        allow(subject).to receive(:hybrid_user).and_return(hybrid_user)
      end

      it 'renders the error template' do
        get action
        expect(response).to render_template(template)
      end
    end
  end

  let(:verify_info_step_complete) { false }
  let(:user) { nil }

  before do
    if user
      stub_sign_in(user)
      controller.idv_session.resolution_successful = verify_info_step_complete
      controller.idv_session.address_verification_mechanism = nil
      controller.idv_session.ssn = nil
    end

    stub_analytics
  end

  describe 'before_actions' do
    it 'includes before_actions from IdvSessionConcern' do
      expect(subject).to have_actions(:before, :redirect_unless_sp_requested_verification)
    end
  end

  describe '#exception' do
    let(:action) { :exception }
    let(:template) { 'idv/session_errors/exception' }
    let(:params) { {} }

    subject(:response) { get action, params: params }

    it_behaves_like 'an idv session errors controller action'
    it_behaves_like 'non-authenticated idv session errors controller action'
  end

  describe '#warning' do
    let(:action) { :warning }
    let(:template) { 'idv/session_errors/warning' }
    let(:params) { {} }

    subject(:response) { get :warning, params: params }

    it_behaves_like 'an idv session errors controller action'
    it_behaves_like 'non-authenticated idv session errors controller action'

    context 'with rate limit attempts' do
      let(:user) { create(:user) }

      before do
        RateLimiter.new(rate_limit_type: :idv_resolution, user: user).increment!
      end

      it 'assigns remaining count' do
        response

        expect(assigns(:remaining_submit_attempts)).to be_kind_of(Numeric)
      end

      it 'assigns URL to try again' do
        response

        expect(assigns(:try_again_path)).to eq(idv_verify_info_url)
      end

      it 'logs an event with attempts remaining' do
        expect(@analytics).to receive(:track_event).with(
          'IdV: session error visited',
          hash_including(
            type: action.to_s,
            submit_attempts_remaining: IdentityConfig.store.idv_max_attempts - 1,
          ),
        )
        response
      end

      context 'in in-person proofing flow' do
        let(:params) { { flow: 'in_person' } }

        it 'assigns URL to try again' do
          response

          expect(assigns(:try_again_path)).to eq(idv_in_person_verify_info_url)
        end
      end
    end
  end

  describe '#state_id_warning' do
    let(:action) { :state_id_warning }
    let(:template) { 'idv/session_errors/state_id_warning' }
    let(:params) { {} }

    subject(:response) { get action, params: params }

    it_behaves_like 'an idv session errors controller action'
    it_behaves_like 'non-authenticated idv session errors controller action'

    describe 'try again URL' do
      let(:user) { create(:user) }

      it 'assigns URL to try again' do
        response
        expect(assigns(:try_again_path)).to eq(idv_verify_info_url)
      end

      context 'in in-person proofing flow' do
        let(:params) { { flow: 'in_person' } }

        it 'assigns URL to try again' do
          response
          expect(assigns(:try_again_path)).to eq(idv_in_person_verify_info_url)
        end
      end
    end
  end

  describe '#failure' do
    let(:action) { :failure }
    let(:template) { 'idv/session_errors/failure' }

    it_behaves_like 'an idv session errors controller action'
    it_behaves_like 'non-authenticated idv session errors controller action'

    context 'while rate limited' do
      let(:user) { create(:user) }

      before do
        RateLimiter.new(rate_limit_type: :idv_resolution, user: user).increment_to_limited!
      end

      it 'assigns expiration time' do
        get action

        expect(assigns(:expires_at)).to be_kind_of(Time)
      end

      it 'assigns sp_name' do
        decorated_sp_session = double
        allow(decorated_sp_session).to receive(:sp_name).and_return('Example SP')
        allow(controller).to receive(:decorated_sp_session).and_return(decorated_sp_session)
        get action
        expect(assigns(:sp_name)).to eql('Example SP')
      end

      it 'logs an event with attempts remaining' do
        expect(@analytics).to receive(:track_event).with(
          'IdV: session error visited',
          hash_including(
            type: action.to_s,
            submit_attempts_remaining: 0,
          ),
        )
        get action
      end
    end
  end

  describe '#ssn_failure' do
    let(:action) { :ssn_failure }
    let(:template) { 'idv/session_errors/failure' }

    it_behaves_like 'an idv session errors controller action'

    context 'while rate limited' do
      let(:user) { build(:user) }
      let(:ssn) { '666666666' }

      around do |ex|
        freeze_time { ex.run }
      end

      before do
        RateLimiter.new(
          rate_limit_type: :proof_ssn,
          target: Pii::Fingerprinter.fingerprint(ssn),
        ).increment_to_limited!
        controller.idv_session.ssn = ssn
      end

      it 'assigns expiration time' do
        get action

        expect(assigns(:expires_at)).not_to eq(Time.zone.now)
      end

      it 'logs an event with attempts remaining' do
        expect(@analytics).to receive(:track_event).with(
          'IdV: session error visited',
          hash_including(
            type: 'ssn_failure',
            submit_attempts_remaining: 0,
          ),
        )
        get action
      end
    end
  end

  describe '#rate_limited' do
    let(:action) { :rate_limited }
    let(:template) { 'idv/session_errors/rate_limited' }

    it_behaves_like 'an idv session errors controller action'
    it_behaves_like 'non-authenticated idv session errors controller action'

    context 'while rate limited' do
      let(:user) { create(:user) }

      before do
        RateLimiter.new(rate_limit_type: :idv_doc_auth, user: user).increment_to_limited!
      end

      it 'assigns expiration time' do
        get action

        expect(assigns(:expires_at)).to be_kind_of(Time)
      end

      it 'logs an event with attempts remaining' do
        expect(@analytics).to receive(:track_event).with(
          'IdV: session error visited',
          hash_including(
            type: action.to_s,
            submit_attempts_remaining: 0,
          ),
        )

        get action
      end
    end
  end
end
