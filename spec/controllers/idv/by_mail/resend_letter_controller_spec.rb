require 'rails_helper'

RSpec.describe Idv::ByMail::ResendLetterController,
               allowed_extra_analytics: [:sample_bucket1, :sample_bucket2] do
  let(:user) { create(:user) }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    stub_sign_in(user)
    stub_analytics
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
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
        hash_including(
          resend: true,
          first_letter_requested_at: user.pending_profile.gpo_verification_pending_at,
          hours_since_first_letter: 24,
        ),
      )

      expect(@analytics).to have_logged_event(
        'IdV: USPS address letter enqueued',
        hash_including(
          resend: true,
          first_letter_requested_at: user.pending_profile.gpo_verification_pending_at,
          hours_since_first_letter: 24,
          enqueued_at: Time.zone.now,
          proofing_components: nil,
        ),
      )
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

  def expect_to_resend_letter_and_redirect
    pii = user.pending_profile.decrypt_pii(user.password).to_h
    pii_cacher = instance_double(Pii::Cacher)
    allow(pii_cacher).to receive(:fetch).with(user.pending_profile.id).and_return(pii)
    allow(pii_cacher).to receive(:exists_in_session?).and_return(true)
    allow(Pii::Cacher).to receive(:new).and_return(pii_cacher)

    service_provider = create(:service_provider, issuer: '123abc')
    session[:sp] = { issuer: service_provider.issuer, vtr: ['C1'] }

    gpo_confirmation_maker = instance_double(GpoConfirmationMaker)
    allow(GpoConfirmationMaker).to receive(:new).
      with(pii: pii, service_provider: service_provider, profile: user.pending_profile).
      and_return(gpo_confirmation_maker)

    expect(gpo_confirmation_maker).to receive(:perform)
    expect { put :create }.to change { ActionMailer::Base.deliveries.count }.by(1)
    expect(response).to redirect_to idv_letter_enqueued_path
  end
end
