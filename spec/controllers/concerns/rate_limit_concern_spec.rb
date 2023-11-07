require 'rails_helper'

RSpec.describe 'RateLimitConcern' do
  let(:user) { create(:user, :fully_registered, email: 'old_email@example.com') }

  idv_step_controller_class = Class.new(ApplicationController) do
    def self.name
      'AnonymousController'
    end

    include RateLimitConcern
    include IdvSession

    def show
      render plain: 'Hello'
    end

    def update
      render plain: 'Bye'
    end
  end

  describe '#confirm_not_rate_limited' do
    controller(idv_step_controller_class) do
      before_action :confirm_not_rate_limited
    end

    before(:each) do
      sign_in(user)
      allow(subject).to receive(:current_user).and_return(user)
      routes.draw do
        get 'show' => 'anonymous#show'
        put 'update' => 'anonymous#update'
      end
    end

    context 'user is not rate limited' do
      let(:user) { create(:user, :fully_registered) }

      it 'does not redirect' do
        get :show

        expect(response.body).to eq 'Hello'
        expect(response.status).to eq 200
      end
    end

    context 'with idv_doc_auth rate_limiter (DocumentCapture)' do
      it 'redirects to idv_doc_auth rate limited error page' do
        rate_limiter = RateLimiter.new(user:, rate_limit_type: :idv_doc_auth)
        rate_limiter.increment_to_limited!

        get :show

        expect(response).to redirect_to idv_session_errors_rate_limited_url
      end
    end

    context 'with idv_resolution rate_limiter (VerifyInfo)' do
      it 'redirects to idv_resolution rate limited error page' do
        rate_limiter = RateLimiter.new(user:, rate_limit_type: :idv_resolution)
        rate_limiter.increment_to_limited!

        get :show

        expect(response).to redirect_to idv_session_errors_failure_url
      end
    end

    context 'with proof_address rate_limiter (PhoneStep)' do
      context 'when the user is phone rate limited' do
        before do
          rate_limiter = RateLimiter.new(user:, rate_limit_type: :proof_address)
          rate_limiter.increment_to_limited!
        end

        it 'does not redirect' do
          get :show

          expect(response.body).to eq 'Hello'
          expect(response.status).to eq 200
        end
      end

      context 'when the user is mail rate limited' do
        before do
          create(
            :profile,
            :verification_cancelled,
            :letter_sends_rate_limited,
            user:,
          )
        end

        it 'does not redirect' do
          get :show

          expect(response.body).to eq 'Hello'
          expect(response.status).to eq 200
        end
      end

      context 'when the user is phone and mail rate limited' do
        before do
          create(
            :profile,
            :verification_cancelled,
            :letter_sends_rate_limited,
            user:,
          )
          rate_limiter = RateLimiter.new(user:, rate_limit_type: :proof_address)
          rate_limiter.increment_to_limited!
        end

        it 'redirects to proof_address rate limited error page' do
          get :show

          expect(response).to redirect_to idv_phone_errors_failure_url
        end
      end
    end

    context 'with proof_ssn rate_limiter (across steps)' do
      let(:ssn) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn] }

      before do
        RateLimiter.new(
          target: Pii::Fingerprinter.fingerprint(ssn),
          rate_limit_type: :proof_ssn,
        ).increment_to_limited!
      end

      context 'ssn is in idv_session' do
        it 'redirects to proof_ssn rate limited error page' do
          subject.idv_session.ssn = ssn
          get :show

          expect(response).to redirect_to idv_session_errors_ssn_failure_url
        end
      end
    end
  end

  describe '#confirm_not_rate_limited_after_doc_auth' do
    controller(idv_step_controller_class) do
      before_action :confirm_not_rate_limited_after_doc_auth
    end

    before(:each) do
      sign_in(user)
      allow(subject).to receive(:current_user).and_return(user)
      routes.draw do
        get 'show' => 'anonymous#show'
        put 'update' => 'anonymous#update'
      end
    end

    it 'redirects if the user is rate limited for a step after doc auth' do
      RateLimiter.new(user:, rate_limit_type: :idv_resolution).increment_to_limited!

      get :show

      expect(response).to redirect_to(idv_session_errors_failure_url)
    end

    it 'does not redirect if the user is rate limited for doc auth' do
      RateLimiter.new(user:, rate_limit_type: :idv_doc_auth).increment_to_limited!

      get :show

      expect(response.body).to eq 'Hello'
      expect(response.status).to eq 200
    end
  end

  describe '#confirm_not_rate_limited_for_phone_address_verification' do
    controller(idv_step_controller_class) do
      before_action :confirm_not_rate_limited_for_phone_address_verification
    end

    before(:each) do
      sign_in(user)
      allow(subject).to receive(:current_user).and_return(user)
      routes.draw do
        get 'show' => 'anonymous#show'
        put 'update' => 'anonymous#update'
      end
    end

    it 'redirects if the user is rate limited for phone address verification' do
      RateLimiter.new(user:, rate_limit_type: :proof_address).increment_to_limited!

      get :show

      expect(response).to redirect_to(idv_phone_errors_failure_url)
    end

    it 'does not redirect if the user is rate limited for idv resolution' do
      RateLimiter.new(user:, rate_limit_type: :idv_doc_auth).increment_to_limited!
      RateLimiter.new(user:, rate_limit_type: :idv_resolution).increment_to_limited!

      get :show

      expect(response.body).to eq 'Hello'
      expect(response.status).to eq 200
    end

    it 'does not redirect if the user is rate limited for mail' do
      create(:profile, :verification_cancelled, :letter_sends_rate_limited, user:)

      get :show

      expect(response.body).to eq 'Hello'
      expect(response.status).to eq 200
    end
  end
end
