require 'rails_helper'

RSpec.describe Users::BackupCodeReminderController do
  let(:user) { create(:user) }

  before do
    stub_sign_in(user) if user
  end

  describe '#show' do
    subject(:response) { get :show }

    it 'flashes successful authentication message' do
      response

      expect(flash[:success]).to eq(t('notices.authenticated_successfully'))
    end

    it 'logs analytics' do
      stub_analytics

      response

      expect(@analytics).to have_logged_event(:backup_code_reminder_visited)
    end

    context 'if signed out' do
      let(:user) { nil }

      it 'redirects to sign in page' do
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe '#update' do
    subject(:response) { post :update, params: params }
    let(:params) { {} }

    it 'assigns user session value acknowledging dismissed reminder' do
      response

      expect(controller.user_session[:dismissed_backup_code_reminder]).to eq(true)
    end

    context 'if user confirms they have codes' do
      let(:params) { { has_codes: 'true' } }

      it 'logs analytics' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(:backup_code_reminder_submitted, has_codes: true)
      end

      it 'redirects to after-sign-in path' do
        expect(response).to redirect_to(account_path)
      end
    end

    context 'if user requests new codes' do
      let(:params) { {} }

      it 'logs analytics' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(:backup_code_reminder_submitted, has_codes: false)
      end

      it 'redirects to backup code regenerate path' do
        expect(response).to redirect_to(backup_code_regenerate_path)
      end
    end

    context 'if signed out' do
      let(:user) { nil }

      it 'redirects to sign in page' do
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
