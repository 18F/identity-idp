require 'rails_helper'

RSpec.describe Idv::ByMail::RequestLetterController do
  let(:user) { create(:user) }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    stub_analytics
    stub_attempts_tracker
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_needed,
        :confirm_mail_not_rate_limited,
        :confirm_profile_not_too_old,
      )
    end

    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_unless_sp_requested_verification)
    end
  end

  describe '#index' do
    before do
      stub_verify_steps_one_and_two(user)
    end

    it 'renders confirmation page' do
      get :index

      expect(response).to have_http_status(200)
      expect(@analytics).to have_logged_event(
        'IdV: request letter visited',
        letter_already_sent: false,
      )
    end

    it 'updates the doc auth log for the user for the usps_address_view event' do
      unstub_analytics
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :index }.to(
        change { doc_auth_log.reload.usps_address_view_count }.from(0).to(1),
      )
    end

    it 'redirects if the user has sent too much mail' do
      allow(controller.gpo_mail_service).to receive(:rate_limited?).and_return(true)
      allow(subject.idv_session).to receive(:address_mechanism_chosen?).
        and_return(true)
      get :index

      expect(response).to redirect_to idv_enter_password_path
    end

    it 'allows a user to request another letter' do
      allow(controller.gpo_mail_service).to receive(:rate_limited?).and_return(false)
      get :index

      expect(response).to be_ok
    end

    it 'assigns the current step indicator step as "verify phone or address"' do
      get :index

      expect(assigns(:step_indicator_current_step)).to eq(:verify_phone_or_address)
    end

    context 'with letter already sent' do
      before do
        allow_any_instance_of(Idv::ByMail::RequestLetterPresenter).
          to receive(:resend_requested?).and_return(true)
      end

      it 'logs visited event' do
        get :index

        expect(@analytics).to have_logged_event(
          'IdV: request letter visited',
          letter_already_sent: true,
        )
      end
    end

    context 'resending a letter' do
      before do
        allow(controller).to receive(:resend_requested?).and_return(true)
      end

      it 'assigns the current step indicator step as "get a letter"' do
        get :index

        expect(assigns(:step_indicator_current_step)).to eq(:get_a_letter)
      end
    end

    context 'user has a pending profile' do
      let(:profile_created_at) { Time.zone.now }
      let(:pending_profile) do
        create(
          :profile,
          :with_pii,
          user: user,
          created_at: profile_created_at,
        )
      end
      before do
        allow(user).to receive(:pending_profile).and_return(pending_profile)
      end

      it 'renders ok' do
        get :index
        expect(response).to be_ok
      end

      context 'but pending profile is too old to send another letter' do
        let(:profile_created_at) { Time.zone.now - 31.days }
        it 'redirects back to /verify' do
          get :index
          expect(response).to redirect_to(idv_path)
        end
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

        expect(response).to redirect_to idv_enter_password_path
        expect(subject.idv_session.address_verification_mechanism).to eq :gpo
      end

      it 'logs USPS address letter requested analytics event with phone step attempts' do
        RateLimiter.new(user: user, rate_limit_type: :proof_address).increment!
        put :create

        expect(@analytics).to have_logged_event(
          'IdV: USPS address letter requested',
          resend: false,
          phone_step_attempts: 1,
          first_letter_requested_at: nil,
          hours_since_first_letter: 0,
          proofing_components: nil,
          **ab_test_args,
        )
      end

      it 'logs attempts api tracking' do
        expect(@irs_attempts_api_tracker).to receive(:idv_gpo_letter_requested).
          with(resend: false)

        put :create
      end

      it 'updates the doc auth log for the user for the usps_letter_sent event' do
        unstub_analytics
        doc_auth_log = DocAuthLog.create(user_id: user.id)

        expect { put :create }.to(
          change { doc_auth_log.reload.usps_letter_sent_submit_count }.from(0).to(1),
        )
      end
    end

    context 'resending a letter' do
      let(:has_pending_profile) { true }
      let(:pending_profile) { create(:profile, :verify_by_mail_pending) }

      before do
        stub_sign_in(user)
        stub_user_with_pending_profile(user)
        allow(user).to receive(:gpo_verification_pending_profile?).and_return(true)
      end

      it 'calls the GpoConfirmationMaker to send another letter and redirects' do
        expect_resend_letter_to_send_letter_and_redirect(otp: false)
      end

      it 'calls GpoConfirmationMaker to send another letter with reveal_gpo_code on' do
        allow(FeatureManagement).to receive(:reveal_gpo_code?).and_return(true)
        expect_resend_letter_to_send_letter_and_redirect(otp: true)
      end

      it 'logs USPS address letter analytics events with phone step attempts', :freeze_time do
        RateLimiter.new(user: user, rate_limit_type: :proof_address).increment!
        expect_resend_letter_to_send_letter_and_redirect(otp: false)

        expect(@analytics).to have_logged_event(
          'IdV: USPS address letter requested',
          resend: true,
          phone_step_attempts: 1,
          first_letter_requested_at: pending_profile.gpo_verification_pending_at,
          hours_since_first_letter: 24,
          proofing_components: nil,
          **ab_test_args,
        )

        expect(@analytics).to have_logged_event(
          'IdV: USPS address letter enqueued',
          resend: true,
          first_letter_requested_at: pending_profile.gpo_verification_pending_at,
          hours_since_first_letter: 24,
          enqueued_at: Time.zone.now,
          phone_step_attempts: 1,
          proofing_components: nil,
          **ab_test_args,
        )
      end

      it 'logs attempts api tracking' do
        expect(@irs_attempts_api_tracker).to receive(:idv_gpo_letter_requested).
          with(resend: true)

        put :create
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
    expect { put :create }.to change { ActionMailer::Base.deliveries.count }.by(1)
    expect(response).to redirect_to idv_letter_enqueued_path
  end
end
