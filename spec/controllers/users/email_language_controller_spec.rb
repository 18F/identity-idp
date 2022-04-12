require 'rails_helper'

RSpec.describe Users::EmailLanguageController do
  describe 'before_actions' do
    it 'includes appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end
  end

  let(:original_email_language) { nil }
  let(:user) { create(:user, email_language: original_email_language) }

  before do
    stub_sign_in(user)
  end

  describe '#show' do
    subject(:action) { get :show }

    it 'renders' do
      action
      expect(response).to render_template(:show)
    end

    it 'logs an analytics event for visiting' do
      stub_analytics
      expect(@analytics).to receive(:track_event).with('Email Language: Visited')

      action
    end
  end

  describe '#update' do
    subject(:action) do
      patch :update, params: { user: { email_language: email_language } }
    end

    context 'with a valid language selection' do
      let(:email_language) { 'es' }

      it 'updates the user email_language' do
        expect { action }.
          to(change { user.reload.email_language }.from(original_email_language).to(email_language))
      end

      it 'redirects to the account page with a success flash' do
        action

        expect(response).to redirect_to account_path
        expect(flash[:success]).to be_present
      end

      it 'logs a successful analytics event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with('Email Language: Updated', hash_including(success: true))

        action
      end
    end

    context 'with an invalid language selection' do
      let(:email_language) { 'zz' }

      it 'does not change the user email_language' do
        expect { action }.to_not(change { user.reload.email_language })
      end

      it 'redirects to the account page, no success flash' do
        action

        expect(response).to redirect_to account_path
        expect(flash[:success]).to be_blank
      end

      it 'logs an unsuccessful analytics event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with('Email Language: Updated', hash_including(success: false))

        action
      end
    end
  end
end
