require 'rails_helper'

RSpec.describe Users::PivCacRecommendedController do
  
  describe 'New user' do
    let(:user) { create(:user, :fully_registered) }
    before do
      stub_sign_in_before_2fa(user)
      stub_analytics
    end

    context '#show' do
      context 'with user with gov email' do
        it 'should render with .gov content ' do
          get :show

          expect(assigns(:email_type)).to eq('.gov')
          expect(response.status).to eq 200
        end
      end

      context 'with user with mil email' do
        let(:user) { build(:user, email: 'test@test.mil') }
        it 'should render with .gov content ' do
          get :show

          expect(assigns(:email_type)).to eq('.mil')
          expect(response.status).to eq 200
        end
      end

      context 'with user without proper email' do
        let(:user) { build(:user, email: 'test@test.com') }

        it 'redirects back to sign in page' do
          expect(response).to redirect_to(authentication_methods_setup_path)
        end
      end
    end
  
    context '#confirm' do
    end
  
    context '#skip' do
    end

  end

  describe 'Sign in flow' do
    before do
      stub_analytics
      user = create(:user, :fully_registered, :with_phone, with: { phone: '703-555-1212' })
      stub_sign_in(user)
    end

    context '#show' do
    end
  
    context '#confirm' do
    end
  
    context '#skip' do
    end
  end
end
