require 'rails_helper'

describe Users::DeleteController do
  include Features::MailerHelper

  describe '#show' do
    it 'shows' do
      stub_signed_in_user
      get :show

      expect(response).to render_template(:show)
    end
  end

  describe '#delete' do
    it 'redirects to the root path' do
      stub_signed_in_user
      post :delete
      expect(response).to redirect_to root_url
    end

    it 'deletes user' do
      user = stub_signed_in_user
      expect(User.where(id: user.id).length).to eq(1)
      post :delete
      expect(User.where(id: user.id).length).to eq(0)
    end

    it 'does not delete identities to prevent uuid reuse' do
      user = stub_signed_in_user
      user.identities << Identity.create(
        service_provider: 'foo',
        last_authenticated_at: Time.zone.now,
      )
      expect(Identity.where(user_id: user.id).length).to eq(1)
      post :delete
      expect(Identity.where(user_id: user.id).length).to eq(1)
    end

    it 'deletes profile information for loa3' do
      profile = create(:profile, :active, :verified, pii: { ssn: '1234', dob: '1920-01-01' })
      stub_sign_in(profile.user)
      expect(Profile.count).to eq(1)
      post :delete
      expect(Profile.count).to eq(0)
    end
  end

  def stub_signed_in_user
    user = create(:user, :signed_up, email: 'old_email@example.com')
    stub_sign_in(user)
  end
end
