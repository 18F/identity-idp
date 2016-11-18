require 'rails_helper'

include Features::MailerHelper
include Features::LocalizationHelper
include Features::ActiveJobHelper

describe Users::RegistrationsController, devise: true do
  describe '#new' do
    context 'When registrations are disabled' do
      it 'prevents users from visiting sign up page' do
        allow(AppSetting).to(receive(:registrations_enabled?)).and_return(false)

        get :new

        expect(response.status).to eq(302)
        expect(response).to redirect_to root_url
      end
    end

    context 'When registrations are enabled' do
      it 'allows user to visit the sign up page' do
        allow(AppSetting).to(receive(:registrations_enabled?)).and_return(true)

        get :new

        expect(response.status).to eq(200)
        expect(response).to render_template(:new)
      end
    end

    it 'triggers completion of "demo" experiment' do
      expect(subject).to receive(:ab_finished).with(:demo)
      get :new
    end
  end

  describe '#create' do
    context 'when registering with a new email' do
      let(:form) do
        instance_double(
          RegisterUserEmailForm, user: User.new(uuid: '123', email: 'new@example.com')
        )
      end

      before do
        stub_analytics

        allow(RegisterUserEmailForm).to receive(:new).and_return(form)
        allow(form).to receive(:submit).with(email: 'new@example.com').and_return(true)
        allow(form).to receive(:email_taken?).and_return(false)
        allow(@analytics).to receive(:track_event)
        allow(subject).to receive(:create_user_event)

        post :create, user: { email: 'new@example.com' }
      end

      it 'tracks successful user registration' do
        expect(@analytics).to have_received(:track_event).
          with(Analytics::USER_REGISTRATION_ACCOUNT_CREATED, user_id: form.user.uuid)
      end

      it 'creates an :account_created event' do
        expect(subject).to have_received(:create_user_event).with(:account_created, form.user)
      end
    end

    it 'tracks successful user registration with existing email' do
      existing_user = create(:user)

      stub_analytics

      form = instance_double(RegisterUserEmailForm)
      allow(RegisterUserEmailForm).to receive(:new).and_return(form)
      allow(form).to receive(:submit).with(email: existing_user.email).and_return(true)
      allow(form).to receive(:email_taken?).and_return(true)
      allow(form).to receive(:email).and_return(existing_user.email)
      allow(form).to receive_message_chain(:user, :email).and_return(existing_user.email)

      expect(@analytics).to receive(:track_event).
        with(Analytics::USER_REGISTRATION_EXISTING_EMAIL, user_id: existing_user.uuid)

      post :create, user: { email: existing_user.email }
    end

    it 'tracks unsuccessful user registration' do
      stub_analytics

      expect(@analytics).to receive(:track_event).
        with(Analytics::USER_REGISTRATION_INVALID_EMAIL, email: 'invalid@')

      post :create, user: { email: 'invalid@' }
    end
  end

  describe '#start' do
    it 'tracks page visit' do
      stub_analytics

      expect(@analytics).to receive(:track_event).
        with(Analytics::ACCOUNT_CREATION_INTRO_VISIT)

      get :start
    end
  end
end
