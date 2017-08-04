require 'rails_helper'

describe Users::VerifyPasswordController do
  let(:user) { create(:user, profiles: profiles, personal_key: personal_key) }
  let(:profiles) { [] }
  let(:recovery_hash) { { personal_key: personal_key } }
  let(:personal_key) { 'key' }

  before do
    stub_sign_in(user)
  end

  context 'without password_reset_profile' do
    describe '#new' do
      it 'redirects user to the home page' do
        get :new

        expect(response).to redirect_to(root_url)
      end
    end
  end

  context 'with password reset profile' do
    let(:profiles) { [create(:profile, deactivation_reason: :password_reset)] }
    let(:response_ok) { FormResponse.new(success: true, errors: {}, extra: { personal_key: key }) }
    let(:response_bad) { FormResponse.new(success: false, errors: {}) }
    let(:key) { 'key' }

    context 'without personal key flag set' do
      describe '#new' do
        it 'redirects to the root url' do
          get :new
          expect(response).to redirect_to(root_url)
        end
      end

      describe '#update' do
        it 'redirects to the root url' do
          get :new
          expect(response).to redirect_to(root_url)
        end
      end
    end

    context 'with personal key flag set' do
      before do
        allow(subject.reactivate_account_session).to receive(:personal_key?).
          and_return(personal_key)
      end

      describe '#new' do
        it 'renders the `new` template' do
          get :new

          expect(response).to render_template(:new)
        end
      end

      describe '#update' do
        let(:form) { instance_double(VerifyPasswordForm) }

        before do
          expect(controller).to receive(:verify_password_form).and_return(form)
        end

        context 'with valid password' do
          before do
            allow(form).to receive(:submit).and_return(response_ok)
            put :update, user: { password: user.password }
          end

          it 'redirects to the account page' do
            expect(response).to redirect_to(account_url)
          end

          it 'sets a new personal key as a flash message' do
            expect(flash[:personal_key]).to eq(key)
          end
        end

        context 'without valid password' do
          it 'renders the new template' do
            allow(form).to receive(:submit).and_return(response_bad)

            put :update, user: { password: user.password }

            expect(response).to render_template(:new)
          end
        end
      end
    end
  end
end
