require 'rails_helper'

RSpec.describe Idv::ByMail::RequestLetterController,
               allowed_extra_analytics: [:sample_bucket1, :sample_bucket2] do
  let(:user) { create(:user) }

  let(:ab_test_args) do
    { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
  end

  before do
    stub_analytics
    allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::ByMail::RequestLetterController.step_info).to be_valid
    end
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_needed,
        :confirm_mail_not_rate_limited,
      )
    end

    it 'includes before_actions from IdvSessionConcern' do
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
      expect(@analytics).to have_logged_event('IdV: request letter visited')
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
  end

  describe '#create' do
    before do
      stub_verify_steps_one_and_two(user)
    end

    it 'invalidates future steps' do
      expect(subject).to receive(:clear_future_steps!)

      put :create
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
        hash_including(
          resend: false,
          phone_step_attempts: 1,
          first_letter_requested_at: nil,
          hours_since_first_letter: 0,
          **ab_test_args,
        ),
      )
    end

    it 'updates the doc auth log for the user for the usps_letter_sent event' do
      unstub_analytics
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { put :create }.to(
        change { doc_auth_log.reload.usps_letter_sent_submit_count }.from(0).to(1),
      )
    end
  end
end
