require 'rails_helper'

RSpec.describe Idv::ByMail::ResendLetterController do
  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
    stub_analytics
  end

  describe '#new' do
    context 'the user has a gpo pending pending profile' do
      before do
        create(:profile, :verify_by_mail_pending, user: user)
      end

      it 'renders the confirmation page' do
        get(:new)

        expect(response).to have_http_status(200)
        expect(@analytics).to have_logged_event(:idv_resend_letter_visited)
      end
    end

    context 'the user does not have a gpo pending profile' do
      it 'redirects to the account page' do
        get(:new)

        expect(response).to redirect_to(account_url)
      end
    end

    context 'the user has a profile that is too old to request a new letter' do
      before do
        create(:profile, :verify_by_mail_pending, created_at: 100.days.ago, user: user)
      end

      it 'redirects to the enter OTP page' do
        get(:new)

        expect(response).to redirect_to(idv_verify_by_mail_enter_code_path)
      end
    end

    context 'the user has sent to much mail' do
      before do
        profile = create(:profile, :verify_by_mail_pending, user: user)
        create_list(:gpo_confirmation_code, 3, profile: profile)
      end

      it 'redirects to the enter OTP page' do
        get(:new)

        expect(response).to redirect_to(idv_verify_by_mail_enter_code_path)
      end
    end
  end

  describe '#new' do
    before do
      create(:profile, :verify_by_mail_pending, :with_pii, user: user)
    end

    it 'uses the GPO confirmation maker to send another letter and redirects', :freeze_time do
      expect_to_resend_letter_and_redirect

      expect(@analytics).to have_logged_event(
        'IdV: USPS address letter requested',
        resend: true,
        first_letter_requested_at: user.pending_profile.gpo_verification_pending_at,
        hours_since_first_letter: 24,
        phone_step_attempts: 0,
      )

      expect(@analytics).to have_logged_event(
        'IdV: USPS address letter enqueued',
        hash_including(
          resend: true,
          first_letter_requested_at: user.pending_profile.gpo_verification_pending_at,
          hours_since_first_letter: 24,
          enqueued_at: Time.zone.now,
        ),
      )
    end

    context 'when using vtr values' do
      it 'uses the GPO confirmation maker to send another letter and redirects', :freeze_time do
        expect_to_resend_letter_and_redirect(vtr: true)

        expect(@analytics).to have_logged_event(
          'IdV: USPS address letter requested',
          resend: true,
          first_letter_requested_at: user.pending_profile.gpo_verification_pending_at,
          hours_since_first_letter: 24,
          phone_step_attempts: 0,
        )

        expect(@analytics).to have_logged_event(
          'IdV: USPS address letter enqueued',
          hash_including(
            resend: true,
            first_letter_requested_at: user.pending_profile.gpo_verification_pending_at,
            hours_since_first_letter: 24,
            enqueued_at: Time.zone.now,
          ),
        )
      end
    end

    it 'redirects to capture password controller if the PII is locked' do
      pii_cacher = instance_double(Pii::Cacher)
      allow(pii_cacher).to receive(:fetch).and_return(nil)
      allow(pii_cacher).to receive(:exists_in_session?).and_return(false)
      allow(Pii::Cacher).to receive(:new).and_return(pii_cacher)

      put :create

      expect(response).to redirect_to capture_password_path
    end
  end

  def expect_to_resend_letter_and_redirect(vtr: false)
    pii = user.pending_profile.decrypt_pii(user.password).to_h
    pii_cacher = instance_double(Pii::Cacher)
    allow(pii_cacher).to receive(:fetch).with(user.pending_profile.id).and_return(pii)
    allow(pii_cacher).to receive(:exists_in_session?).and_return(true)
    allow(Pii::Cacher).to receive(:new).and_return(pii_cacher)

    service_provider = create(:service_provider, issuer: '123abc')
    session[:sp] = { issuer: service_provider.issuer }

    if vtr
      session[:sp][:vtr] = ['C1']
    else
      session[:sp][:acr_values] = Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF
    end

    gpo_confirmation_maker = instance_double(GpoConfirmationMaker)
    allow(GpoConfirmationMaker).to receive(:new)
      .with(pii: pii, service_provider: service_provider, profile: user.pending_profile)
      .and_return(gpo_confirmation_maker)

    expect(gpo_confirmation_maker).to receive(:perform)
    expect { put :create }.to change { ActionMailer::Base.deliveries.count }.by(1)
    expect(response).to redirect_to idv_letter_enqueued_path
  end
end
