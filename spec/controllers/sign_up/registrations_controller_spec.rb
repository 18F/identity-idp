require 'rails_helper'

describe SignUp::RegistrationsController, devise: true do
  include Features::MailerHelper
  include Features::LocalizationHelper
  include Features::ActiveJobHelper

  describe '#new' do
    it 'allows user to visit the sign up page' do
      get :new

      expect(response.status).to eq(200)
      expect(response).to render_template(:new)
    end

    it 'cannot be viewed by signed in users' do
      stub_sign_in

      subject.session[:sp] = { request_url: 'http://test.com' }

      get :new

      expect(response).to redirect_to account_path
    end

    it 'gracefully handles invalid formats' do
      @request.env['HTTP_ACCEPT'] = "nessus=bad_bad_value'"
      get :new

      expect(response.status).to eq(200)
    end
  end

  describe '#create' do
    context 'when registering with a new email' do
      it 'tracks successful user registration with recaptcha enabled' do
        stub_analytics

        allow(@analytics).to receive(:track_event)
        allow(subject).to receive(:create_user_event)

        captcha_h = mock_captcha(enabled: true, present: true, valid: true)

        post :create, params: { user: { email: 'new@example.com' }, 'g-recaptcha-response': 'foo' }

        user = User.find_with_email('new@example.com')

        analytics_hash = {
          success: true,
          errors: {},
          email_already_exists: false,
          user_id: user.uuid,
          domain_name: 'example.com',
        }.merge(captcha_h)

        expect(@analytics).to have_received(:track_event).
          with(Analytics::USER_REGISTRATION_EMAIL, analytics_hash)

        expect(subject).to have_received(:create_user_event).with(:account_created, user)
      end

      it 'tracks successful user registration with recaptcha disabled' do
        stub_analytics

        allow(@analytics).to receive(:track_event)
        allow(subject).to receive(:create_user_event)

        captcha_h = mock_captcha(enabled: false, present: false, valid: true)

        post :create, params: { user: { email: 'new@example.com' } }

        user = User.find_with_email('new@example.com')

        analytics_hash = {
          success: true,
          errors: {},
          email_already_exists: false,
          user_id: user.uuid,
          domain_name: 'example.com',
        }.merge(captcha_h)

        expect(@analytics).to have_received(:track_event).
          with(Analytics::USER_REGISTRATION_EMAIL, analytics_hash)

        expect(subject).to have_received(:create_user_event).with(:account_created, user)
      end

      it 'sets the email in the session and redirects to sign_up_verify_email_path' do
        post :create, params: { user: { email: 'test@test.com' } }

        expect(session[:email]).to eq('test@test.com')
        expect(response).to redirect_to(sign_up_verify_email_path)
      end

      it 'cannot be accessed by signed in users' do
        user = create(:user)
        stub_sign_in(user)

        post :create, params: { user: { email: user.email } }

        expect(response).to redirect_to account_path
      end

      it 'prevents a bot from registering' do
        stub_analytics

        allow(@analytics).to receive(:track_event)
        allow(subject).to receive(:create_user_event)

        captcha_h = mock_captcha(enabled: true, present: true, valid: false)

        post :create, params: { user: { email: 'new@example.com' }, 'g-recaptcha-response': 'foo' }

        user = User.find_with_email('new@example.com')
        expect(user).to be_nil

        analytics_hash = {
          success: false,
          errors: {},
          email_already_exists: false,
          user_id: 'anonymous-uuid',
          domain_name: 'example.com',
        }.merge(captcha_h)

        expect(@analytics).to have_received(:track_event).
          with(Analytics::USER_REGISTRATION_EMAIL, analytics_hash)

        expect(response).to render_template(:new)
      end

      it 'prevents a user from registering if they bypass the captcha' do
        stub_analytics

        allow(@analytics).to receive(:track_event)
        allow(subject).to receive(:create_user_event)

        captcha_h = mock_captcha(enabled: true, present: false, valid: false)

        post :create, params: { user: { email: 'new@example.com' }, 'g-recaptcha-response': '' }

        user = User.find_with_email('new@example.com')
        expect(user).to be_nil

        analytics_hash = {
          success: false,
          errors: {},
          email_already_exists: false,
          user_id: 'anonymous-uuid',
          domain_name: 'example.com',
        }.merge(captcha_h)

        expect(@analytics).to have_received(:track_event).
          with(Analytics::USER_REGISTRATION_EMAIL, analytics_hash)

        expect(response).to render_template(:new)
      end

      it 'prevents a bot from registering if they do not send the captcha' do
        stub_analytics

        allow(@analytics).to receive(:track_event)
        allow(subject).to receive(:create_user_event)

        captcha_h = mock_captcha(enabled: true, present: false, valid: false)

        post :create, params: { user: { email: 'new@example.com' } }

        user = User.find_with_email('new@example.com')
        expect(user).to be_nil

        analytics_hash = {
          success: false,
          errors: {},
          email_already_exists: false,
          user_id: 'anonymous-uuid',
          domain_name: 'example.com',
        }.merge(captcha_h)

        expect(@analytics).to have_received(:track_event).
          with(Analytics::USER_REGISTRATION_EMAIL, analytics_hash)

        expect(response).to render_template(:new)
      end
    end

    it 'tracks successful user registration with existing email' do
      existing_user = create(:user, email: 'test@example.com')

      stub_analytics

      captcha_h = mock_captcha(enabled: true, present: true, valid: true)
      analytics_hash = {
        success: true,
        errors: {},
        email_already_exists: true,
        user_id: existing_user.uuid,
        domain_name: 'example.com',
      }.merge(captcha_h)

      expect(@analytics).to receive(:track_event).
        with(Analytics::USER_REGISTRATION_EMAIL, analytics_hash)
      expect(subject).to_not receive(:create_user_event)

      post :create, params: { user: { email: 'TEST@example.com ' }, 'g-recaptcha-response': 'foo' }
    end

    it 'tracks unsuccessful user registration' do
      stub_analytics

      captcha_h = mock_captcha(enabled: true, present: true, valid: true)
      analytics_hash = {
        success: false,
        errors: { email: [t('valid_email.validations.email.invalid')] },
        email_already_exists: false,
        user_id: 'anonymous-uuid',
        domain_name: 'invalid',
      }.merge(captcha_h)

      expect(@analytics).to receive(:track_event).
        with(Analytics::USER_REGISTRATION_EMAIL, analytics_hash)

      post :create, params: { user: { email: 'invalid@', request_id: '' },
                              'g-recaptcha-response': 'foo' }
    end

    it 'renders new if email is nil' do
      post :create, params: { user: { request_id: '123789' } }

      expect(response).to render_template(:new)
    end

    it 'renders new if email is a Hash' do
      put :create, params: { user: { email: { foo: 'bar' } } }

      expect(response).to render_template(:new)
    end

    it 'renders new if request_id is blank' do
      post :create, params: { user: { email: 'invalid@' } }

      expect(response).to render_template(:new)
    end
  end

  describe '#show' do
    it 'tracks page visit' do
      stub_analytics

      expect(@analytics).to receive(:track_event).
        with(Analytics::USER_REGISTRATION_INTRO_VISIT)

      get :show, params: { request_id: 'foo' }
    end

    it 'cannot be viewed by signed in users' do
      stub_sign_in

      get :show

      expect(response).to redirect_to account_path
    end

    it 'redirects to sign_up_email_path if request_id param is missing' do
      get :show

      expect(response).to redirect_to sign_up_email_path
    end
  end

  def mock_captcha(enabled:, present:, valid:)
    allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(enabled)
    allow_any_instance_of(SignUp::RegistrationsController).to receive(:verify_recaptcha).
      and_return(valid)
    {
      recaptcha_valid: valid,
      recaptcha_present: present,
      recaptcha_enabled: enabled,
    }
  end
end
