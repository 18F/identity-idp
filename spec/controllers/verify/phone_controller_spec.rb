require 'rails_helper'
include Features::LocalizationHelper

describe Verify::PhoneController do
  let(:good_phone) { '+1 (555) 555-0000' }
  let(:bad_phone) { '+1 (555) 555-5555' }

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_session_started,
        :confirm_idv_attempts_allowed
      )
    end
  end

  describe '#new' do
    it 'redirects to review when step is complete' do
      user = build(:user, phone: good_phone, phone_confirmed_at: Time.zone.now)
      stub_subject(user)
      subject.idv_session.phone_confirmation = true

      get :new

      expect(response).to redirect_to verify_review_path
    end
  end

  describe '#create' do
    context 'when form is invalid' do
      render_views

      before do
        user = build(:user, phone: '+1 (415) 555-0130')
        stub_subject(user)
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      it 'renders #new' do
        put :create, idv_phone_form: { phone: '703' }

        expect(response.body).to have_content invalid_phone_message
        expect(subject.idv_session.params).to be_empty
      end

      it 'tracks form error and does not make a vendor API call' do
        allow(Idv::PhoneValidator).to receive(:new)

        put :create, idv_phone_form: { phone: '703' }

        result = {
          success: false,
          errors: {
            phone: [invalid_phone_message]
          }
        }

        expect(@analytics).to have_received(:track_event).with(
          Analytics::IDV_PHONE_CONFIRMATION, result
        )
        expect(subject.idv_session.phone_confirmation).to eq false
        expect(Idv::PhoneValidator).to_not have_received(:new)
      end
    end

    context 'when form is valid' do
      before do
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      it 'tracks event with valid phone' do
        user = build(:user, phone: good_phone, phone_confirmed_at: Time.zone.now)
        stub_subject(user)

        put :create, idv_phone_form: { phone: good_phone }

        result = { success: true, errors: {} }

        expect(@analytics).to have_received(:track_event).with(
          Analytics::IDV_PHONE_CONFIRMATION, result
        )
      end

      it 'tracks event with invalid phone' do
        user = build(:user, phone: bad_phone, phone_confirmed_at: Time.zone.now)
        stub_subject(user)

        put :create, idv_phone_form: { phone: bad_phone }

        result = {
          success: false,
          errors: {
            phone: ['The phone number could not be verified.']
          }
        }

        expect(@analytics).to have_received(:track_event).with(
          Analytics::IDV_PHONE_CONFIRMATION, result
        )
      end

      context 'when same as user phone' do
        it 'redirects to review page and sets phone_confirmed_at' do
          user = build(:user, phone: good_phone, phone_confirmed_at: Time.zone.now)
          stub_subject(user)

          put :create, idv_phone_form: { phone: good_phone }

          expect(response).to redirect_to verify_review_path

          expected_params = {
            phone: good_phone,
            phone_confirmed_at: user.phone_confirmed_at
          }
          expect(subject.idv_session.params).to eq expected_params
        end
      end

      context 'when different from user phone' do
        it 'redirects to review page and does not set phone_confirmed_at' do
          user = build(:user, phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now)
          stub_subject(user)

          put :create, idv_phone_form: { phone: good_phone }

          expect(response).to redirect_to verify_review_path

          expected_params = {
            phone: good_phone
          }
          expect(subject.idv_session.params).to eq expected_params
        end
      end
    end
  end

  def stub_subject(user)
    user_session = {}
    stub_sign_in(user)
    idv_session = Idv::Session.new(user_session, user)
    idv_session.resolution = Proofer::Resolution.new success: true, session_id: 'some-id'
    idv_session.applicant = Proofer::Applicant.new first_name: 'Some', last_name: 'One'
    idv_session.vendor = subject.idv_vendor.pick
    allow(subject).to receive(:confirm_idv_session_started).and_return(true)
    allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
    allow(subject).to receive(:idv_session).and_return(idv_session)
    allow(subject).to receive(:user_session).and_return(user_session)
  end
end
