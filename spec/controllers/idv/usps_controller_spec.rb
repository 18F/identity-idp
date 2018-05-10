require 'rails_helper'

require 'proofer/vendor/mock'

describe Idv::UspsController do
  let(:user) { create(:user) }

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_session_started,
        :confirm_mail_not_spammed
      )
    end
  end

  describe '#index' do
    before do
      stub_verify_steps_one_and_two(user)
    end

    it 'renders confirmation page' do
      get :index

      expect(response).to be_ok
    end

    it 'redirects if the user has sent too much mail' do
      allow(controller.usps_mail_service).to receive(:mail_spammed?).and_return(true)
      allow(subject.idv_session).to receive(:address_mechanism_chosen?).
        and_return(true)
      get :index

      expect(response).to redirect_to idv_review_path
    end

    it 'allows a user to request another letter' do
      allow(controller.usps_mail_service).to receive(:mail_spammed?).and_return(false)
      get :index

      expect(response).to be_ok
    end
  end

  describe '#create' do
    context 'first time through the idv process' do
      before do
        stub_verify_steps_one_and_two(user)
      end

      it 'sets session to :usps and redirects' do
        expect(subject.idv_session.address_verification_mechanism).to be_nil

        put :create

        expect(response).to redirect_to idv_review_path
        expect(subject.idv_session.address_verification_mechanism).to eq :usps
      end
    end

    context 'resending a letter' do
      let(:has_pending_profile) { true }
      let(:pending_profile) { create(:profile, phone_confirmed: false) }

      before do
        stub_sign_in(user)
        stub_decorated_user_with_pending_profile(user)
        allow(user.decorate).to receive(:needs_profile_usps_verification?).and_return(true)
      end

      it 'calls the UspsConfirmationMaker to send another letter and redirects' do
        pii = { first_name: 'Samuel', last_name: 'Sampson' }
        pii_cacher = instance_double(Pii::Cacher)
        allow(pii_cacher).to receive(:fetch).and_return(pii)
        allow(Pii::Cacher).to receive(:new).and_return(pii_cacher)

        session[:sp] = { issuer: '123abc' }

        usps_confirmation_maker = instance_double(UspsConfirmationMaker)
        allow(UspsConfirmationMaker).to receive(:new).
          with(pii: pii, issuer: '123abc', profile: pending_profile).
          and_return(usps_confirmation_maker)

        expect(usps_confirmation_maker).to receive(:perform)

        put :create

        expect(response).to redirect_to idv_come_back_later_path
      end
    end
  end
end
