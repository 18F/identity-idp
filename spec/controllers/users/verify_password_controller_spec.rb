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
        let(:password) { nil }
        let(:user_params) { { user: { password: } } }

        context 'with valid password' do
          let(:password) { user.password }

          before do
            pii = Pii::Attributes.new_from_hash(Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN)
            ReactivateAccountSession.new(
              user:,
              user_session: controller.user_session,
            ).store_decrypted_pii(pii)

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

          it 'sets the new personal key as a user session value' do
            expect(controller.user_session[:personal_key]).to match(/^([A-Z0-9]{4}(-|$)){4}/)
          end
        end

        context 'without valid password' do
          let(:password) { user.password + 'wrong' }

          render_views

          before do
            put :update, params: user_params
          end

          it 'logs an appropriate analytics event' do
            expect(@analytics).to have_logged_event(
              :reactivate_account_verify_password_submitted,
              success: false,
              error_details: { password: { password_incorrect: true } },
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
