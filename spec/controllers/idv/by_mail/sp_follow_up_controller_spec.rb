require 'rails_helper'

RSpec.describe Idv::ByMail::SpFollowUpController do
  let(:post_idv_follow_up_url) { 'https://example.com/follow_up' }
  let(:initiating_service_provider) { create(:service_provider, post_idv_follow_up_url:) }
  let(:user) { create(:user, :fully_registered) }
  let!(:profile) { create(:profile, :active, user:, initiating_service_provider:) }

  before do
    stub_sign_in(user) if user.present?
    stub_analytics
  end

  describe '#new' do
    context 'the user has not finished verification' do
      let(:profile) do
        create(:profile, :verify_by_mail_pending, user:, initiating_service_provider:)
      end

      it 'redirects to the account page' do
        get :new

        expect(response).to redirect_to(account_url)
      end
    end

    context 'the user has an SP in the session' do
      before do
        allow(controller).to receive(:current_sp).and_return(initiating_service_provider)
      end

      it 'redirects to the account page' do
        get :new

        expect(response).to redirect_to(account_url)
      end
    end

    context 'the user does not have an initiating service provider' do
      let(:profile) { create(:profile, :active, user:, initiating_service_provider: nil) }

      it 'redirects to the account page' do
        get :new

        expect(response).to redirect_to(account_url)
      end
    end

    it 'logs analytics and renders the template' do
      get :new

      expect(response).to render_template(:new)
      expect(@analytics).to have_logged_event(
        :idv_by_mail_sp_follow_up_visited,
        initiating_service_provider: initiating_service_provider.issuer,
      )
    end
  end

  describe '#show' do
    it 'logs analytics and redirects to the service provider' do
      get :show

      expect(response).to redirect_to(post_idv_follow_up_url)
      expect(@analytics).to have_logged_event(
        :idv_by_mail_sp_follow_up_submitted,
        initiating_service_provider: initiating_service_provider.issuer,
      )
    end
  end

  describe '#cancel' do
    it 'logs analytics and redirects to the account URL' do
      get :cancel

      expect(response).to redirect_to(account_url)
      expect(@analytics).to have_logged_event(
        :idv_by_mail_sp_follow_up_cancelled,
        initiating_service_provider: initiating_service_provider.issuer,
      )
    end
  end
end
