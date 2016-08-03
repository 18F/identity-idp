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

    it 'tracks the pageview' do
      stub_analytics
      expect(@analytics).to receive(:track_pageview)

      get :new
    end
  end

  describe '#create' do
    it 'tracks successful user registration' do
      stub_analytics

      form = instance_double(RegisterUserEmailForm)
      allow(RegisterUserEmailForm).to receive(:new).and_return(form)
      allow(form).to receive(:submit).with(email: 'new@example.com').and_return(true)
      allow(form).to receive(:email_taken?).and_return(false)
      allow(form).to receive_message_chain(:user, :email).and_return('new@example.com')

      expect(@analytics).to receive(:track_event).with('Account Created', form.user)

      post :create, user: { email: 'new@example.com' }
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

  describe '#start' do
    it 'tracks the pageview' do
      stub_analytics
      expect(@analytics).to receive(:track_pageview)

      get :start
    end
  end
end
