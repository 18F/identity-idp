describe Devise::AccountTypeController, devise: true do
  render_views

  describe 'GET /resource/type' do
    context 'when the user already has an account type' do
      it 'redirects to dashboard' do
        sign_in_as_user
        patch :set_type, user: { account_type: 'self' }
        get :type

        expect(response).to redirect_to('/dashboard')
        expect(flash[:error]).to include('cannot change account type')
      end
    end

    context 'when the user does not already have an account type' do
      it 'renders the account type selection' do
        user = create(:user, :all_but_account_type)
        sign_in(user)
        get :type

        expect(response).to render_template(:type)
      end
    end
  end

  describe 'PATCH /resource/set_type' do
    it "updates the user's account_type when params are valid" do
      user = create(:user, :all_but_account_type)

      sign_in(user)
      patch :set_type, user: { account_type: 'self' }
      user.reload

      expect(user.account_type).to eq('self')
    end

    it 'flashes error when params are invalid' do
      user = create(:user, :all_but_account_type)

      sign_in(user)
      patch :set_type, user: { account_type: 'foo' }

      expect(response).to render_template(:type)
      expect(flash[:error]).to eq t('upaya.errors.no_account_type')
    end

    it "doesn't change the user's existing account_type" do
      user = create(:user, :signed_up, account_type: 'representative')

      sign_in(user)

      expect(user.account_type).to eq('representative')

      patch :set_type, user: { account_type: 'self' }
      user.reload

      expect(user.account_type).to eq('representative')
    end
  end
end
