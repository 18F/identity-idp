require 'rails_helper'

RSpec.describe Users::VerifyPasswordController do
  let(:key) { 'key' }
  let(:profiles) { [] }
  let(:recovery_hash) { { personal_key: key } }
  let(:user) { create(:user, profiles: profiles, **recovery_hash) }

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
    let(:profiles) { [create(:profile, :password_reset)] }

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
        allow(subject.reactivate_account_session).to receive(:validated_personal_key?).
          and_return(key)
      end

      describe '#new' do
        it 'renders the `new` template' do
          get :new

          expect(response).to render_template(:new)
        end
      end

      describe '#update' do
        let(:form) { instance_double(VerifyPasswordForm) }
        let(:user_params) { { user: { password: user.password } } }

        before do
          stub_attempts_tracker
          allow(@irs_attempts_api_tracker).to receive(
            :logged_in_profile_change_reauthentication_submitted,
          )
          allow(@irs_attempts_api_tracker).to receive(:idv_personal_key_generated)
          expect(controller).to receive(:verify_password_form).and_return(form)
        end

        context 'with valid password' do
          let(:response_ok) { FormResponse.new(success: true, errors: {}, extra: recovery_hash) }

          before do
            allow(form).to receive(:submit).and_return(response_ok)
            put :update, params: user_params
          end

          it 'tracks the appropriate attempts api events' do
            expect(@irs_attempts_api_tracker).to have_received(
              :logged_in_profile_change_reauthentication_submitted,
            ).with({ success: true })
            expect(@irs_attempts_api_tracker).to have_received(:idv_personal_key_generated)
          end

          it 'redirects to the account page' do
            expect(response).to redirect_to(account_url)
          end

          it 'sets a new personal key as a flash message' do
            expect(flash[:personal_key]).to eq(key)
          end
        end

        context 'without valid password' do
          let(:response_bad) { FormResponse.new(success: false, errors: {}) }

          render_views

          before do
            allow(form).to receive(:submit).and_return(response_bad)

            put :update, params: user_params
          end

          it 'tracks the appropriate attempts api event' do
            expect(@irs_attempts_api_tracker).to have_received(
              :logged_in_profile_change_reauthentication_submitted,
            ).with({ success: false })
            expect(@irs_attempts_api_tracker).not_to have_received(:idv_personal_key_generated)
          end

          it 'renders the new template' do
            expect(response).to render_template(:new)
          end
        end
      end
    end
  end
end
