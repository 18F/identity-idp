require 'rails_helper'

describe Idv::SessionsController do
  let(:max_attempts) { Idv::Attempter.idv_max_attempts }
  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
  let(:user_attrs) do
    {
      first_name: 'Some',
      last_name: 'One',
      ssn: '666-66-1234',
      dob: '19720329',
      address1: '123 Main St',
      address2: '',
      city: 'Somewhere',
      state: 'VA',
      zipcode: '66044',
      state_id_type: 'drivers_license',
      state_id_number: '123456789',
    }
  end
  let(:idv_session) do
    Idv::Session.new(user_session: subject.user_session, current_user: user, issuer: nil)
  end

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_attempts_allowed,
        :confirm_idv_needed,
        :confirm_step_needed,
      )
    end
  end

  before do
    stub_sign_in(user)
    allow(subject).to receive(:idv_session).and_return(idv_session)
    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  describe '#new' do
    it 'starts a new proofing session' do
      get :new

      expect(response.status).to eq 200
    end

    context 'the user has already completed the step' do
      it 'redirects to the success step' do
        idv_session.profile_confirmation = true
        idv_session.resolution_successful = true

        get :new

        expect(response).to redirect_to idv_session_success_path
      end
    end

    context 'max attempts exceeded' do
      it 'redirects to fail' do
        user.idv_attempts = max_attempts
        user.idv_attempted_at = Time.zone.now

        get :new

        result = {
          request_path: idv_session_path,
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::IDV_MAX_ATTEMPTS_EXCEEDED, result)
        expect(response).to redirect_to idv_session_failure_url(:fail)
      end
    end
  end

  describe '#create' do
    it 'assigns a UUID to the applicant' do
      post :create, params: { profile: user_attrs }

      expect(subject.idv_session.applicant['uuid']).to eq subject.current_user.uuid
    end

    it 'redirects to failure if the SSN exists' do
      create(:profile, pii: { ssn: '666-66-1234' })

      context = { stages: [{ resolution: 'ResolutionMock' }, { state_id: 'StateIdMock' }] }
      result = {
        success: false,
        idv_attempts_exceeded: false,
        errors: {},
        ssn_is_unique: false,
        vendor: { messages: [], context: context, exception: nil, timed_out: false },
      }

      expect(@analytics).to receive(:track_event).ordered.
        with(Analytics::IDV_BASIC_INFO_SUBMITTED_FORM, hash_including(success: true))
      expect(@analytics).to receive(:track_event).ordered.
        with(Analytics::IDV_BASIC_INFO_SUBMITTED_VENDOR, result)

      post :create, params: { profile: user_attrs.merge(ssn: '666-66-1234') }

      expect(response).to redirect_to(idv_session_failure_url(:warning))
      expect(idv_session.profile_confirmation).to be_falsy
      expect(idv_session.resolution_successful).to be_falsy
    end

    it 'renders the forms if there are missing fields' do
      partial_attrs = user_attrs.tap { |attrs| attrs.delete :first_name }

      result = {
        success: false,
        errors: { first_name: [t('errors.messages.blank')] },
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::IDV_BASIC_INFO_SUBMITTED_FORM, result)

      expect { post :create, params: { profile: partial_attrs } }.
        to_not change(user, :idv_attempts)

      expect(response).to render_template(:new)
      expect(flash[:warning]).to be_nil
      expect(idv_session.profile_confirmation).to be_falsy
      expect(idv_session.resolution_successful).to be_falsy
    end

    it 'redirects to the warning page and increments attempts when verification fails' do
      user_attrs[:first_name] = 'Bad'

      context = { stages: [{ resolution: 'ResolutionMock' }] }
      result = {
        success: false,
        idv_attempts_exceeded: false,
        errors: {
          first_name: ['Unverified first name.'],
        },
        ssn_is_unique: true,
        vendor: { messages: [], context: context, exception: nil, timed_out: false },
      }

      expect(@analytics).to receive(:track_event).ordered.
        with(Analytics::IDV_BASIC_INFO_SUBMITTED_FORM, hash_including(success: true))
      expect(@analytics).to receive(:track_event).ordered.
        with(Analytics::IDV_BASIC_INFO_SUBMITTED_VENDOR, result)

      expect { post :create, params: { profile: user_attrs } }.
        to change(user, :idv_attempts).by(1)

      expect(response).to redirect_to(idv_session_failure_url(:warning))
      expect(idv_session.profile_confirmation).to be_falsy
      expect(idv_session.resolution_successful).to be_falsy
    end

    it 'redirects to the success page when verification succeeds' do
      context = { stages: [{ resolution: 'ResolutionMock' }, { state_id: 'StateIdMock' }] }
      result = {
        success: true,
        idv_attempts_exceeded: false,
        errors: {},
        ssn_is_unique: true,
        vendor: { messages: [], context: context, exception: nil, timed_out: false },
      }

      expect(@analytics).to receive(:track_event).ordered.
        with(Analytics::IDV_BASIC_INFO_SUBMITTED_FORM, hash_including(success: true))
      expect(@analytics).to receive(:track_event).ordered.
        with(Analytics::IDV_BASIC_INFO_SUBMITTED_VENDOR, result)

      expect { post :create, params: { profile: user_attrs } }.
        to change(user, :idv_attempts).by(1)

      expect(response).to redirect_to(idv_session_success_url)
      expect(idv_session.profile_confirmation).to eq(true)
      expect(idv_session.resolution_successful).to eq(true)
    end

    it 'redirects to the fail page when max attempts are exceeded' do
      user.idv_attempts = max_attempts
      user.idv_attempted_at = Time.zone.now

      post :create, params: { profile: user_attrs }

      result = {
        request_path: idv_session_path,
      }

      expect(@analytics).to have_received(:track_event).
        with(Analytics::IDV_MAX_ATTEMPTS_EXCEEDED, result)
      expect(response).to redirect_to idv_session_failure_url(:fail)
      expect(idv_session.profile_confirmation).to be_falsy
      expect(idv_session.resolution_successful).to be_falsy
    end
  end

  describe '#failure' do
    it 'renders the error for the the given error case if the failure reason' do
      expect(controller).to receive(:render_idv_step_failure).with(:sessions, :fail)

      get :failure, params: { reason: :fail }
    end
  end

  context 'user has created account' do
    describe '#failure' do
      let(:reason) { :fail }

      it 'calls `render_step_failure` with step_name of :sessions and the reason' do
        expect(controller).to receive(:render_idv_step_failure).with(:sessions, reason)

        get :failure, params: { reason: reason }
      end
    end
  end

  describe '#destroy' do
    it 'tracks an analytics event' do
      stub_analytics

      expect(@analytics).to receive(:track_event).
        with(Analytics::IDV_VERIFICATION_ATTEMPT_CANCELLED)

      delete(:destroy)
    end
  end
end
