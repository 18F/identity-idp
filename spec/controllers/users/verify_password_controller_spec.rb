require 'rails_helper'

RSpec.describe Users::VerifyPasswordController do
  let(:key) { 'key' }
  let(:profiles) { [] }
  let(:recovery_hash) { { personal_key: key } }
  let(:user) { create(:user, profiles: profiles, **recovery_hash) }

  before do
    stub_analytics
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
    let(:profiles) { [create(:profile, :verified, :password_reset)] }

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
        allow(subject.reactivate_account_session).to receive(:validated_personal_key?)
          .and_return(key)
      end

      describe '#new' do
        it 'renders the `new` template' do
          get :new

          expect(response).to render_template(:new)
        end

        it 'logs an analytics event' do
          get :new
          expect(@analytics).to have_logged_event(:reactivate_account_verify_password_visited)
        end
      end

      describe '#update' do
        let(:form) { instance_double(VerifyPasswordForm) }
        let(:user_params) { { user: { password: user.password } } }

        before do
          expect(controller).to receive(:verify_password_form).and_return(form)
        end

        context 'with valid password' do
          let(:response_ok) { FormResponse.new(success: true, errors: {}, extra: recovery_hash) }

          before do
            allow(form).to receive(:submit).and_return(response_ok)
            put :update, params: user_params
          end

          it 'logs an appropriate analytics event' do
            expect(@analytics).to have_logged_event(
              :reactivate_account_verify_password_submitted,
              success: true,
            )
          end

          it 'redirects to the manage personal key page' do
            expect(response).to redirect_to(manage_personal_key_url)
          end

          it 'sets a new personal key as a flash message' do
            expect(controller.user_session[:personal_key]).to eq(key)
          end
        end

        context 'without valid password' do
          let(:response_bad) { FormResponse.new(success: false, errors: {}) }

          render_views

          before do
            allow(form).to receive(:submit).and_return(response_bad)

            put :update, params: user_params
          end

          it 'logs an appropriate analytics event' do
            expect(@analytics).to have_logged_event(
              :reactivate_account_verify_password_submitted,
              success: false,
            )
          end

          it 'renders the new template' do
            expect(response).to render_template(:new)
          end
        end
      end
    end
  end
end
