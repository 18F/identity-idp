require 'rails_helper'

describe Idv::GpoController do
  let(:user) { create(:user) }

  before { stub_analytics }

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_needed,
        :confirm_mail_not_spammed,
      )
    end

    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  describe '#index' do
    before do
      stub_verify_steps_one_and_two(user)
    end

    it 'renders confirmation page' do
      get :index

      expect(response).to be_ok
      expect(@analytics).to have_logged_event(
        'IdV: USPS address visited',
        letter_already_sent: false,
      )
    end

    it 'redirects if the user has sent too much mail' do
      allow(controller.gpo_mail_service).to receive(:mail_spammed?).and_return(true)
      allow(subject.idv_session).to receive(:address_mechanism_chosen?).
        and_return(true)
      get :index

      expect(response).to redirect_to idv_review_path
    end

    it 'allows a user to request another letter' do
      allow(controller.gpo_mail_service).to receive(:mail_spammed?).and_return(false)
      get :index

      expect(response).to be_ok
    end

    it 'renders wait page while job is in progress' do
      allow(controller).to receive(:async_state).and_return(
        ProofingSessionAsyncResult.new(
          status: ProofingSessionAsyncResult::IN_PROGRESS,
        ),
      )
      get :index

      expect(response).to render_template :wait
    end

    it 'logs an event when there is a timeout' do
      allow(controller).to receive(:async_state).and_return(
        ProofingSessionAsyncResult.new(
          status: ProofingSessionAsyncResult::MISSING,
        ),
      )

      get :index
      expect(@analytics).to have_logged_event('Proofing Address Result Missing', {})
    end

    context 'with letter already sent' do
      before do
        allow_any_instance_of(Idv::GpoPresenter).to receive(:letter_already_sent?).and_return(true)
      end

      it 'logs visited event' do
        get :index

        expect(@analytics).to have_logged_event(
          'IdV: USPS address visited',
          letter_already_sent: true,
        )
      end
    end
  end

  describe '#create' do
    context 'first time through the idv process' do
      before do
        stub_verify_steps_one_and_two(user)
      end

      it 'sets session to :gpo and redirects' do
        expect(subject.idv_session.address_verification_mechanism).to be_nil

        put :create

        expect(response).to redirect_to idv_review_path
        expect(subject.idv_session.address_verification_mechanism).to eq :gpo
      end
    end

    context 'resending a letter' do
      let(:has_pending_profile) { true }
      let(:pending_profile) { create(:profile) }

      before do
        stub_sign_in(user)
        stub_decorated_user_with_pending_profile(user)
        allow(user.decorate).to receive(:pending_profile_requires_verification?).and_return(true)
      end

      it 'calls the GpoConfirmationMaker to send another letter and redirects' do
        expect_resend_letter_to_send_letter_and_redirect(otp: false)
      end

      it 'calls GpoConfirmationMaker to send another letter with reveal_gpo_code on' do
        allow(FeatureManagement).to receive(:reveal_gpo_code?).and_return(true)
        expect_resend_letter_to_send_letter_and_redirect(otp: true)
      end

      it 'redirects to capture password if pii is locked' do
        pii_cacher = instance_double(Pii::Cacher)
        allow(pii_cacher).to receive(:fetch).and_return(nil)
        allow(pii_cacher).to receive(:exists_in_session?).and_return(false)
        allow(Pii::Cacher).to receive(:new).and_return(pii_cacher)

        put :create

        expect(response).to redirect_to capture_password_path
      end
    end
  end

  def expect_resend_letter_to_send_letter_and_redirect(otp:)
    pii = { first_name: 'Samuel', last_name: 'Sampson' }
    pii_cacher = instance_double(Pii::Cacher)
    allow(pii_cacher).to receive(:fetch).and_return(pii)
    allow(pii_cacher).to receive(:exists_in_session?).and_return(true)
    allow(Pii::Cacher).to receive(:new).and_return(pii_cacher)

    service_provider = create(:service_provider, issuer: '123abc')
    session[:sp] = { issuer: service_provider.issuer }

    gpo_confirmation_maker = instance_double(GpoConfirmationMaker)
    allow(GpoConfirmationMaker).to receive(:new).
      with(pii: pii, service_provider: service_provider, profile: pending_profile).
      and_return(gpo_confirmation_maker)

    expect(gpo_confirmation_maker).to receive(:perform)
    expect(gpo_confirmation_maker).to receive(:otp) if otp

    put :create

    expect(response).to redirect_to idv_come_back_later_path
  end
end
