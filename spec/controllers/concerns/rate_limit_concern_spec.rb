require 'rails_helper'

RSpec.describe 'RateLimitConcern' do
  let(:user) { create(:user, :fully_registered, email: 'old_email@example.com') }

  module Idv
    class StepController < ApplicationController
      include RateLimitConcern
      include IdvSession

      def show
        render plain: 'Hello'
      end

      def update
        render plain: 'Bye'
      end
    end
  end

  describe '#confirm_not_rate_limited' do
    controller Idv::StepController do
      before_action :confirm_not_rate_limited
    end

    before(:each) do
      sign_in(user)
      allow(subject).to receive(:current_user).and_return(user)
      allow(subject).to receive(:flow_session).and_return({})
      routes.draw do
        get 'show' => 'idv/step#show'
        put 'update' => 'idv/step#update'
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
        rate_limiter = RateLimiter.new(user: user, rate_limit_type: :idv_doc_auth)
        rate_limiter.increment_to_limited!

        get :show

        expect(response).to redirect_to idv_session_errors_rate_limited_url
      end
    end

    context 'with idv_resolution rate_limiter (VerifyInfo)' do
      it 'redirects to idv_resolution rate limited error page' do
        rate_limiter = RateLimiter.new(user: user, rate_limit_type: :idv_resolution)
        rate_limiter.increment_to_limited!

        get :show

        expect(response).to redirect_to idv_session_errors_failure_url
      end
    end

    context 'with proof_address rate_limiter (PhoneStep)' do
      before do
        rate_limiter = RateLimiter.new(user: user, rate_limit_type: :proof_address)
        rate_limiter.increment_to_limited!
      end

      it 'redirects to proof_address rate limited error page' do
        get :show

        expect(response).to redirect_to idv_phone_errors_failure_url
      end
    end
  end
end
