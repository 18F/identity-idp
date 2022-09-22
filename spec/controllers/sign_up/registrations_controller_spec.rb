require 'rails_helper'

describe SignUp::RegistrationsController, devise: true do
  include Features::MailerHelper

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

      expect { get :new }.
        to raise_error(Mime::Type::InvalidMimeType)
    end
  end

  describe '#create' do
    let(:success_properties) { { success: true, failure_reason: nil } }
    context 'when registering with a new email' do
      it 'tracks successful user registration' do
        stub_analytics
        stub_attempts_tracker

        allow(@analytics).to receive(:track_event)
        allow(subject).to receive(:create_user_event)

        expect(@irs_attempts_api_tracker).to receive(:user_registration_email_submitted).with(
          email: 'new@example.com',
          **success_properties,
        )

        post :create, params: { user: { email: 'new@example.com', terms_accepted: '1' } }

        user = User.find_with_email('new@example.com')

        analytics_hash = {
          success: true,
          throttled: false,
          errors: {},
          email_already_exists: false,
          user_id: user.uuid,
          domain_name: 'example.com',
        }

        expect(@analytics).to have_received(:track_event).
          with('User Registration: Email Submitted', analytics_hash)

        expect(subject).to have_received(:create_user_event).with(:account_created, user)
      end

      it 'sets the users preferred email locale and sends an email in that locale' do
        post :create, params: { user: { email: 'test@test.com', email_language: 'es',
                                        terms_accepted: '1' } }

        expect(User.find_with_email('test@test.com').email_language).to eq('es')

        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).
          to eq(I18n.t('user_mailer.email_confirmation_instructions.subject', locale: 'es'))
      end

      it 'sets the email in the session and redirects to sign_up_verify_email_path' do
        post :create, params: { user: { email: 'test@test.com', terms_accepted: '1' } }

        expect(session[:email]).to eq('test@test.com')
        expect(response).to redirect_to(sign_up_verify_email_path)
      end

      it 'cannot be accessed by signed in users' do
        user = create(:user)
        stub_sign_in(user)

        post :create, params: { user: { email: user.email, terms_accepted: '1' } }

        expect(response).to redirect_to account_path
      end
    end

    it 'tracks successful user registration with existing email' do
      existing_user = create(:user, email: 'test@example.com')

      stub_analytics
      stub_attempts_tracker

      analytics_hash = {
        success: true,
        throttled: false,
        errors: {},
        email_already_exists: true,
        user_id: existing_user.uuid,
        domain_name: 'example.com',
      }

      expect(@analytics).to receive(:track_event).
        with('User Registration: Email Submitted', analytics_hash)

      expect(@irs_attempts_api_tracker).to receive(:user_registration_email_submitted).with(
        email: 'TEST@example.com ',
        **success_properties,
      )

      expect(subject).to_not receive(:create_user_event)

      post :create, params: { user: { email: 'TEST@example.com ', terms_accepted: '1' } }
    end

    it 'tracks unsuccessful user registration' do
      stub_analytics
      stub_attempts_tracker

      analytics_hash = {
        success: false,
        throttled: false,
        errors: { email: [t('valid_email.validations.email.invalid')] },
        error_details: { email: [:invalid] },
        email_already_exists: false,
        user_id: 'anonymous-uuid',
        domain_name: 'invalid',
      }

      expect(@analytics).to receive(:track_event).
        with('User Registration: Email Submitted', analytics_hash)

      expect(@irs_attempts_api_tracker).to receive(:track_event).with(
        :user_registration_email_submitted,
        email: 'invalid@',
        success: false,
        failure_reason: { email: [:invalid] },
      )

      post :create, params: { user: { email: 'invalid@', request_id: '', terms_accepted: '1' } }
    end

    it 'renders new if email is nil' do
      post :create, params: { user: { request_id: '123789', terms_accepted: '1' } }

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
end
