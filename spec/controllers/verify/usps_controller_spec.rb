require 'rails_helper'

require 'proofer/vendor/mock'

describe Verify::UspsController do
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

      expect(response).to redirect_to verify_review_path
    end

    it 'allows a user to request another letter' do
      allow(controller.usps_mail_service).to receive(:mail_spammed?).and_return(false)
      get :index

      expect(response).to be_ok
    end
  end

  describe '#create' do
    before do
      stub_verify_steps_one_and_two(user)
    end

    it 'sets session to :usps and redirects' do
      expect(subject.idv_session.address_verification_mechanism).to be_nil

      put :create

      expect(response).to redirect_to verify_review_path
      expect(subject.idv_session.address_verification_mechanism).to eq :usps
    end
  end
end
