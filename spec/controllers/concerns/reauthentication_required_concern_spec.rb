require 'rails_helper'

describe ReauthenticationRequiredConcern do
  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }

  class ReauthenticationRequiredController < ApplicationController
    include ReauthenticationRequiredConcern

    before_action :confirm_recently_authenticated

    def show
      render plain: 'Hello'
    end
  end

  describe '#confirm_recently_authenticated' do
    controller ReauthenticationRequiredController do
    end

    before(:each) do
      stub_sign_in(user)
      routes.draw do
        get 'show' => 'reauthentication_required#show'
      end
    end

    context 'recently authenticated' do
      it 'allows action' do
        get :show

        expect(response.body).to eq 'Hello'
      end
    end

    context 'authenticated outside the authn window' do
      before do
        controller.user_session[:authn_at] -= IdentityConfig.store.reauthn_window
      end

      it 'redirects to password confirmation' do
        get :show

        expect(response).to redirect_to user_password_confirm_url
      end

      it 'sets context to authentication' do
        get :show

        expect(controller.user_session[:context]).to eq 'reauthentication'
      end
    end
  end
end
