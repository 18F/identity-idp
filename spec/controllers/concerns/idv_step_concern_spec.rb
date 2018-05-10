require 'rails_helper'

describe 'IdvStepConcern' do
  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
  let(:idv_session) do
    Idv::Session.new(user_session: subject.user_session, current_user: user, issuer: nil)
  end

  module Idv
    class StepController < ApplicationController
      include IdvStepConcern
    end
  end

  describe '#confirm_idv_attempts_allowed' do
    controller Idv::StepController do
      before_action :confirm_idv_attempts_allowed

      def show
        render plain: 'Hello'
      end
    end

    before(:each) do
      stub_sign_in(user)
      routes.draw do
        get 'show' => 'idv/step#show'
      end
    end

    context 'user has exceeded IdV max attempts in a single session' do
      before do
        user.idv_attempts = 3
        user.idv_attempted_at = Time.zone.now
        allow(subject).to receive(:confirm_idv_session_started).and_return(true)
      end

      it 'redirects to hardfail page' do
        get :show

        expect(response).to redirect_to idv_fail_url
      end
    end

    context 'user has exceeded IdV max attempts in a single period' do
      before do
        allow(subject).to receive(:confirm_idv_session_started).and_return(true)
        user.idv_attempts = 3
        user.idv_attempted_at = Time.zone.now
      end

      it 'redirects to hardfail page' do
        get :show

        expect(response).to redirect_to idv_fail_url
      end
    end

    context 'user attempts IdV after window has passed' do
      before do
        allow(subject).to receive(:confirm_idv_session_started).and_return(true)
        user.idv_attempts = 3
        user.idv_attempted_at = Time.zone.now - 25.hours
        get :show
      end

      it 'allows request to proceed' do
        expect(response.body).to eq 'Hello'
      end

      it 'resets user attempt count' do
        expect(user.idv_attempts).to eq 0
      end
    end
  end

  describe '#confirm_idv_session_started' do
    controller Idv::StepController do
      before_action :confirm_idv_session_started

      def show
        render plain: 'Hello'
      end
    end

    before(:each) do
      stub_sign_in(user)
      routes.draw do
        get 'show' => 'idv/step#show'
      end
    end

    context 'user has not started IdV session' do
      before do
        allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
      end

      it 'redirects to idv session url' do
        get :show

        expect(response).to redirect_to(idv_session_url)
      end
    end

    context 'user has started IdV session' do
      before do
        idv_session.params = { first_name: 'Jane' }
        allow(subject).to receive(:idv_session).and_return(idv_session)
      end

      it 'allows request' do
        get :show

        expect(response.body).to eq 'Hello'
      end
    end
  end

  describe '#confirm_idv_needed' do
    controller Idv::StepController do
      before_action :confirm_idv_needed

      def show
        render plain: 'Hello'
      end
    end

    before(:each) do
      sign_in(user)
      routes.draw do
        get 'show' => 'idv/step#show'
      end
    end

    context 'user has active profile' do
      before do
        allow(user).to receive(:active_profile).and_return(Profile.new)
        allow(subject).to receive(:current_user).and_return(user)
        allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
        allow(subject).to receive(:confirm_idv_session_started).and_return(true)
      end

      it 'redirects to activated page' do
        get :show

        expect(response).to redirect_to idv_activated_url
      end
    end

    context 'user does not have active profile' do
      before do
        allow(subject).to receive(:current_user).and_return(user)
        allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
        allow(subject).to receive(:confirm_idv_session_started).and_return(true)
      end

      it 'does not redirect to activated page' do
        get :show

        expect(response.body).to eq 'Hello'
        expect(response).to_not redirect_to idv_activated_url
        expect(response.status).to eq 200
      end
    end
  end
end
