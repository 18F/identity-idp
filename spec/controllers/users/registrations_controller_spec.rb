require 'rails_helper'

include Features::MailerHelper
include Features::LocalizationHelper
include Features::ActiveJobHelper

describe Users::RegistrationsController, devise: true do
  describe '#new' do
    it 'triggers completion of "demo" experiment' do
      expect(subject).to receive(:ab_finished).with(:demo)
      get :new
    end
  end

  describe '#create' do
    context 'when registering with a new email' do
      let(:form) { instance_double(RegisterUserEmailForm) }

      before do
        stub_analytics

        allow(RegisterUserEmailForm).to receive(:new).and_return(form)
        allow(form).to receive(:submit).with(email: 'new@example.com').and_return(true)
        allow(form).to receive(:email_taken?).and_return(false)
        allow(form).to receive_message_chain(:user, :email).and_return('new@example.com')
        allow(@analytics).to receive(:track_event)
        allow(subject).to receive(:create_user_event)

        post :create, user: { email: 'new@example.com' }
      end

      it 'tracks successful user registration' do
        expect(@analytics).to have_received(:track_event).with('Account Created', form.user)
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
        with('Registration Attempt with existing email', existing_user)

      post :create, user: { email: existing_user.email }
    end

    it 'tracks unsuccessful user registration' do
      stub_analytics

      expect(@analytics).to receive(:track_anonymous_event).
        with('User Registration: invalid email', 'invalid@')

      post :create, user: { email: 'invalid@' }
    end
  end
end
