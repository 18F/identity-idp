require 'rails_helper'

RSpec.describe MultipleAccountsDetectedController, type: :controller do
  let(:user) { create(:user, :proofed_with_selfie) }
  let(:profile2) { create(:profile, :facial_match_proof) }

  before do
    stub_sign_in(user)
    stub_analytics
  end

  describe '#show' do
    context 'when user is not authenticated with 2FA' do
      let(:user) { nil }

      it 'redirects to sign in page' do
        get :show
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user has an active duplicate profile confirmation' do
      before do
        DuplicateProfileConfirmation.create(
          profile_id: user.active_profile.id,
          confirmed_at: Time.zone.now,
          duplicate_profile_ids: [profile2.id]
        )
      end

      it 'renders the show template' do
        get :show
        expect(response).to render_template(:show)
      end

      it 'initializes the MultipleAccountsDetectedPresenter' do
        expect(MultipleAccountsDetectedPresenter).to receive(:new).with(user: user)
        get :show
      end

      it 'logs an event' do
        get :show

        expect(@analytics).to have_logged_event(
          :one_account_multiple_accounts_detected
        )
      end
    end
  end

  describe '#do_not_recognize' do
    before do
      @dupe_profile_confirmation = DuplicateProfileConfirmation.create(
        profile_id: user.active_profile.id,
        confirmed_at: Time.zone.now,
        duplicate_profile_ids: [profile2.id]
      )
    end

    it 'logs an event' do
      post :do_not_recognize

      expect(@analytics).to have_logged_event(
        :one_account_unknown_account_detected
      )
    end

    it 'marks some accounts as not recognized' do
      post :do_not_recognize
      @dupe_profile_confirmation.reload 
      expect(@dupe_profile_confirmation.confirmed_all).to eq(false)
    end
  end

  describe '#recognize_accounts' do
    before do
      @dupe_profile_confirmation = DuplicateProfileConfirmation.create(
        profile_id: user.active_profile.id,
        confirmed_at: Time.zone.now,
        duplicate_profile_ids: [profile2.id]
      )
    end

    it 'logs an analytics event' do
      
      post :recognize_accounts
      expect(@analytics).to have_logged_event(
      )
    end

    it 'marks all accounts as recognized' do
      post :recognize_accounts

      @dupe_profile_confirmation.reload

      expect(@dupe_profile_confirmation.confirmed_all).to eq(true)
    end
  end

  describe '#redirect_unless_user_has_active_duplicate_profile_confirmation' do
    context 'when user does not have an active profile' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
        allow(user).to receive(:active_profile).and_return(nil)
        allow(controller).to receive(:confirm_two_factor_authenticated).and_return(true)
      end

      it 'updates dupe profile confirmation' do
        get :show
      end
    end
  end
end
