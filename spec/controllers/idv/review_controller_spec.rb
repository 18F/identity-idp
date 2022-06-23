require 'rails_helper'

describe Idv::ReviewController do
  let(:user) do
    create(
      :user,
      :signed_up,
      password: ControllerHelper::VALID_PASSWORD,
      email: 'old_email@example.com',
    )
  end
  let(:zipcode) { '66044' }
  let(:user_attrs) do
    {
      first_name: 'José',
      last_name: 'One',
      dob: 'March 29, 1972',
      address1: '123 Main St',
      address2: '',
      city: 'Somewhere',
      state: 'KS',
      zipcode: zipcode,
      phone: MfaContext.new(user).phone_configurations.first&.phone,
      ssn: '12345678',
    }
  end
  let(:idv_session) do
    idv_session = Idv::Session.new(
      user_session: subject.user_session,
      current_user: user,
      service_provider: nil,
    )
    idv_session.profile_confirmation = true
    idv_session.vendor_phone_confirmation = true
    idv_session.applicant = user_attrs
    idv_session
  end

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_session_started,
        :confirm_idv_steps_complete,
      )
    end

    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  describe '#confirm_idv_steps_complete' do
    controller do
      before_action :confirm_idv_steps_complete

      def show
        render plain: 'Hello'
      end
    end

    before(:each) do
      stub_sign_in(user)
      routes.draw do
        get 'show' => 'idv/review#show'
      end
      idv_session.applicant = user_attrs
      allow(subject).to receive(:idv_session).and_return(idv_session)
    end

    context 'user has missed address step' do
      before do
        idv_session.vendor_phone_confirmation = false
      end

      it 'redirects to address step' do
        get :show

        expect(response).to redirect_to idv_phone_path
      end
    end
  end

  describe '#confirm_idv_phone_confirmed' do
    controller do
      before_action :confirm_idv_phone_confirmed

      def show
        render plain: 'Hello'
      end
    end

    before(:each) do
      stub_sign_in(user)
      allow(subject).to receive(:idv_session).and_return(idv_session)
      routes.draw do
        get 'show' => 'idv/review#show'
      end
    end

    context 'user is verifying by mail' do
      before do
        allow(idv_session).to receive(:address_verification_mechanism).and_return('gpo')
      end

      it 'does not redirect' do
        get :show

        expect(response.body).to eq 'Hello'
      end
    end

    context 'user phone is confirmed' do
      before do
        allow(idv_session).to receive(:address_verification_mechanism).and_return('phone')
        allow(idv_session).to receive(:phone_confirmed?).and_return(true)
      end

      it 'does not redirect' do
        get :show

        expect(response.body).to eq 'Hello'
      end
    end

    context 'user phone is not confirmed' do
      before do
        allow(idv_session).to receive(:address_verification_mechanism).and_return('phone')
        allow(idv_session).to receive(:phone_confirmed?).and_return(false)
      end

      it 'redirects to phone confirmation' do
        get :show

        expect(response).to redirect_to idv_otp_verification_path
      end
    end
  end

  describe '#confirm_current_password' do
    controller do
      before_action :confirm_current_password

      def show
        render plain: 'Hello'
      end
    end

    before(:each) do
      stub_sign_in(user)
      routes.draw do
        post 'show' => 'idv/review#show'
      end
      allow(subject).to receive(:confirm_idv_steps_complete).and_return(true)
      idv_session.applicant = user_attrs.merge(phone_confirmed_at: Time.zone.now)
      allow(subject).to receive(:idv_session).and_return(idv_session)
    end

    context 'user does not provide password' do
      it 'redirects to new' do
        post :show, params: { user: { password: '' } }

        expect(flash[:error]).to eq t('idv.errors.incorrect_password')
        expect(response).to redirect_to idv_review_path
      end
    end

    context 'user provides wrong password' do
      it 'redirects to new' do
        post :show, params: { user: { password: 'wrong' } }

        expect(flash[:error]).to eq t('idv.errors.incorrect_password')
        expect(response).to redirect_to idv_review_path
      end
    end

    context 'user provides correct password' do
      it 'allows request to proceed' do
        post :show, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        expect(response.body).to eq 'Hello'
      end
    end
  end

  describe '#new' do
    before do
      stub_sign_in(user)
      allow(subject).to receive(:confirm_idv_session_started).and_return(true)
    end

    context 'user has completed all steps' do
      before do
        idv_session.applicant = user_attrs
      end

      it 'shows completed session' do
        get :new

        expect(response).to render_template :new
      end

      it 'displays a helpful flash message to the user' do
        get :new

        expect(flash.now[:success]).to eq(
          t(
            'idv.messages.review.info_verified_html',
            phone_message: "<strong>#{t('idv.messages.phone.phone_of_record')}</strong>",
          ),
        )
      end

      it 'shows steps' do
        get :new

        expect(subject.view_assigns['step_indicator_steps']).not_to include(
          hash_including(name: :verify_phone_or_address, status: :pending),
        )
      end

      context 'idv app password confirm step is enabled' do
        before do
          allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).
            and_return(['password_confirm'])
        end

        it 'redirects to idv app' do
          get :new

          expect(response).to redirect_to idv_app_path
        end
      end
    end

    context 'user chooses address verification' do
      before do
        idv_session.address_verification_mechanism = 'gpo'
      end

      it 'shows revises steps to show pending address verification' do
        get :new

        expect(subject.view_assigns['step_indicator_steps']).to include(
          hash_including(name: :verify_phone_or_address, status: :pending),
        )
      end
    end

    context 'user has not requested too much mail' do
      before do
        idv_session.address_verification_mechanism = 'gpo'
        gpo_mail_service = instance_double(Idv::GpoMail)
        allow(Idv::GpoMail).to receive(:new).with(user).and_return(gpo_mail_service)
        allow(gpo_mail_service).to receive(:mail_spammed?).and_return(false)
      end

      it 'displays a success message' do
        get :new

        expect(flash.now[:error]).to be_nil
      end
    end

    context 'user has requested too much mail' do
      before do
        idv_session.address_verification_mechanism = 'gpo'
        gpo_mail_service = instance_double(Idv::GpoMail)
        allow(Idv::GpoMail).to receive(:new).with(user).and_return(gpo_mail_service)
        allow(gpo_mail_service).to receive(:mail_spammed?).and_return(true)
      end

      it 'displays a helpful error message' do
        get :new

        expect(flash.now[:error]).to eq t('idv.errors.mail_limit_reached')
        expect(flash.now[:success]).to be_nil
      end
    end
  end

  describe '#create' do
    before do
      stub_sign_in(user)
      allow(subject).to receive(:confirm_idv_session_started).and_return(true)
    end

    context 'user fails to supply correct password' do
      before do
        idv_session.applicant = user_attrs.merge(phone_confirmed_at: Time.zone.now)
      end

      it 'redirects to original path' do
        put :create, params: { user: { password: 'wrong' } }

        expect(response).to redirect_to idv_review_path
      end
    end

    context 'user has completed all steps' do
      before do
        idv_session.applicant = user_attrs
        idv_session.applicant = idv_session.vendor_params
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      it 'redirects to personal key path' do
        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        expect(@analytics).to have_received(:track_event).with('IdV: review complete')
        expect(@analytics).to have_received(:track_event).with(
          'IdV: final resolution',
          success: true,
        )
        expect(response).to redirect_to idv_personal_key_path
      end

      it 'redirects to confirmation path after user presses the back button' do
        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        expect(subject.user_session[:need_personal_key_confirmation]).to eq(true)

        allow_any_instance_of(User).to receive(:active_profile).and_return(true)
        get :new
        expect(response).to redirect_to idv_personal_key_path
      end

      it 'creates Profile with applicant attributes' do
        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        profile = idv_session.profile
        pii = profile.decrypt_pii(ControllerHelper::VALID_PASSWORD)

        expect(pii.zipcode).to eq zipcode

        expect(idv_session.applicant[:first_name]).to eq 'José'
        expect(pii.first_name).to eq 'José'
      end

      context 'user picked phone confirmation' do
        before do
          idv_session.address_verification_mechanism = 'phone'
          idv_session.vendor_phone_confirmation = true
          idv_session.user_phone_confirmation = true
        end

        it 'activates profile' do
          put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

          profile = idv_session.profile
          profile.reload

          expect(profile).to be_active
        end

        it 'creates an `account_verified` event once per confirmation' do
          put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
          disavowal_event_count = user.events.where(event_type: :account_verified, ip: '0.0.0.0').
            where.not(disavowal_token_fingerprint: nil).count
          expect(disavowal_event_count).to eq 1
        end

        context 'with idv app personal key step enabled' do
          before do
            allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).
              and_return(['password_confirm', 'personal_key', 'personal_key_confirm'])
          end

          it 'redirects to idv app personal key path' do
            put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

            expect(response).to redirect_to idv_app_url
          end
        end
      end

      context 'user picked GPO confirmation' do
        before do
          idv_session.address_verification_mechanism = 'gpo'
        end

        it 'leaves profile deactivated' do
          put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

          profile = idv_session.profile
          profile.reload

          expect(profile).to_not be_active
        end
      end
    end
  end
end
