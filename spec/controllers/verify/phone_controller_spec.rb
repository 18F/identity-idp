require 'rails_helper'
include Features::LocalizationHelper

describe Verify::PhoneController do
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

  describe '#create' do
    context 'when form is invalid' do
      render_views

      it 'renders #new' do
        user = build(:user, phone: '+1 (415) 555-0130')
        stub_subject(user)

        put :create, idv_phone_form: { phone: '703' }

        expect(response.body).to have_content invalid_phone_message
        expect(subject.idv_session.params).to be_empty
      end
    end

    context 'when form is valid and submitted phone is same as user phone' do
      it 'redirects to review page and sets phone_confirmed_at' do
        user = build(:user, phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now)
        stub_subject(user)

        put :create, idv_phone_form: { phone: '+1 (415) 555-0130' }

        expect(response).to redirect_to verify_review_path

        expected_params = {
          phone: '+1 (415) 555-0130',
          phone_confirmed_at: user.phone_confirmed_at
        }
        expect(subject.idv_session.params).to eq expected_params
      end
    end

    context 'when form is valid and submitted phone is different from user phone' do
      it 'redirects to review page and does not set phone_confirmed_at' do
        user = build(:user, phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now)
        stub_subject(user)

        put :create, idv_phone_form: { phone: '+1 (415) 555-0160' }

        expect(response).to redirect_to verify_review_path

        expected_params = {
          phone: '+1 (415) 555-0160'
        }
        expect(subject.idv_session.params).to eq expected_params
      end
    end
  end

  def stub_subject(user)
    user_session = {}
    stub_sign_in(user)
    idv_session = Idv::Session.new(user_session, user)
    allow(subject).to receive(:confirm_idv_session_started).and_return(true)
    allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
    allow(subject).to receive(:idv_session).and_return(idv_session)
    allow(subject).to receive(:user_session).and_return(user_session)
  end
end
