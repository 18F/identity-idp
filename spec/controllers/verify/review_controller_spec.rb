require 'rails_helper'

require 'proofer/vendor/mock'

describe Verify::ReviewController do
  let(:user) do
    create(
      :user,
      :signed_up,
      password: ControllerHelper::VALID_PASSWORD,
      email: 'old_email@example.com'
    )
  end
  let(:raw_zipcode) { '66044' }
  let(:norm_zipcode) { '66044-1234' }
  let(:normalized_first_name) { 'JOSE' }
  let(:user_attrs) do
    {
      first_name: 'José',
      last_name: 'One',
      ssn: '666661234',
      dob: 'March 29, 1972',
      address1: '123 Main St',
      address2: '',
      city: 'Somewhere',
      state: 'KS',
      zipcode: raw_zipcode,
      phone: user.phone,
      ccn: '12345678',
    }
  end
  let(:idv_session) do
    idv_session = Idv::Session.new(
      user_session: subject.user_session,
      current_user: user,
      issuer: nil
    )
    idv_session.profile_confirmation = true
    idv_session.vendor_phone_confirmation = true
    idv_session.params = user_attrs
    idv_session.normalized_applicant_params = user_attrs.merge(
      zipcode: norm_zipcode, first_name: normalized_first_name
    )
    idv_session
  end

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_session_started,
        :confirm_idv_steps_complete
      )
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
        get 'show' => 'verify/review#show'
      end
      idv_session.params = user_attrs
      allow(subject).to receive(:idv_session).and_return(idv_session)
      allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
    end

    context 'user has missed address step' do
      before do
        idv_session.vendor_phone_confirmation = false
      end

      it 'redirects to address step' do
        get :show

        expect(response).to redirect_to verify_address_path
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
        get 'show' => 'verify/review#show'
      end
    end

    context 'user is verifying by mail' do
      before do
        allow(idv_session).to receive(:address_verification_mechanism).and_return('usps')
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

        expect(response).to redirect_to otp_send_path(
          otp_delivery_selection_form: { otp_delivery_preference: :sms }
        )
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
        post 'show' => 'verify/review#show'
      end
      allow(subject).to receive(:confirm_idv_steps_complete).and_return(true)
      allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
      idv_session.params = user_attrs.merge(phone_confirmed_at: Time.zone.now)
      allow(subject).to receive(:idv_session).and_return(idv_session)
    end

    context 'user does not provide password' do
      it 'redirects to new' do
        post :show, params: { user: { password: '' } }

        expect(flash[:error]).to eq t('idv.errors.incorrect_password')
        expect(response).to redirect_to verify_review_path
      end
    end

    context 'user provides wrong password' do
      it 'redirects to new' do
        post :show, params: { user: { password: 'wrong' } }

        expect(flash[:error]).to eq t('idv.errors.incorrect_password')
        expect(response).to redirect_to verify_review_path
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
      allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
    end

    context 'user has completed all steps' do
      before do
        idv_session.params = user_attrs
      end

      it 'shows completed session' do
        get :new

        expect(response).to render_template :new
      end

      it 'displays a helpful flash message to the user' do
        get :new

        expect(flash.now[:success]).to eq(
          t('idv.messages.review.info_verified_html',
            phone_message: "<strong>#{t('idv.messages.phone.phone_of_record')}</strong>")
        )
      end
    end

    context 'user chooses address verification' do
      before do
        idv_session.address_verification_mechanism = 'usps'
      end

      it 'displays a helpful flash message to the user' do
        get :new

        expect(flash.now[:success]).to eq(
          t('idv.messages.mail_sent')
        )
      end
    end

    context 'user has not requested too much mail' do
      before do
        idv_session.address_verification_mechanism = 'usps'
        usps_mail_service = instance_double(Idv::UspsMail)
        allow(Idv::UspsMail).to receive(:new).with(user).and_return(usps_mail_service)
        allow(usps_mail_service).to receive(:mail_spammed?).and_return(false)
      end

      it 'displays a success message' do
        get :new

        expect(flash.now[:success]).to eq t('idv.messages.mail_sent')
        expect(flash.now[:error]).to be_nil
      end
    end

    context 'user has requested too much mail' do
      before do
        idv_session.address_verification_mechanism = 'usps'
        usps_mail_service = instance_double(Idv::UspsMail)
        allow(Idv::UspsMail).to receive(:new).with(user).and_return(usps_mail_service)
        allow(usps_mail_service).to receive(:mail_spammed?).and_return(true)
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
      allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
    end

    context 'user fails to supply correct password' do
      before do
        idv_session.params = user_attrs.merge(phone_confirmed_at: Time.zone.now)
      end

      it 'redirects to original path' do
        put :create, params: { user: { password: 'wrong' } }

        expect(response).to redirect_to verify_review_path
      end
    end

    context 'user has completed all steps' do
      before do
        idv_session.params = user_attrs
        idv_session.applicant = idv_session.vendor_params
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      it 'redirects to confirmation path' do
        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        expect(@analytics).to have_received(:track_event).with(Analytics::IDV_REVIEW_COMPLETE)
        expect(response).to redirect_to verify_confirmations_path
      end

      it 'creates Profile with applicant and normalized_applicant attributes' do
        put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }

        profile = idv_session.profile
        uak = user.unlock_user_access_key(ControllerHelper::VALID_PASSWORD)
        pii = profile.decrypt_pii(uak)

        expect(pii.zipcode.raw).to eq raw_zipcode
        expect(pii.zipcode.norm).to eq norm_zipcode

        expect(idv_session.applicant[:first_name]).to eq 'Jose'
        expect(pii.first_name.raw).to eq 'José'
        expect(pii.first_name.norm).to eq 'JOSE'
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
          event_creator = instance_double(CreateVerifiedAccountEvent)
          expect(CreateVerifiedAccountEvent).to receive(:new).and_return(event_creator)
          expect(event_creator).to receive(:call)

          put :create, params: { user: { password: ControllerHelper::VALID_PASSWORD } }
        end
      end

      context 'user picked USPS confirmation' do
        before do
          idv_session.address_verification_mechanism = 'usps'
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
