require 'rails_helper'

RSpec.describe Users::EmailsController do
  describe '#verify' do
    context 'with malformed payload' do
      it 'does not blow up' do
        expect { get :verify, params: { request_id: { foo: 'bar' } } }.
          to_not raise_error
      end
    end
  end

  context 'user visits add an email address page' do
    let(:user) { create(:user) }

    before do
      stub_sign_in(user)
      stub_analytics
    end

    it 'renders the show view' do
      get :show

      expect(@analytics).to have_logged_event('Add Email Address Page Visited')
    end
  end

  context 'user visits add an email address from SP consent flow' do
    let(:user) { create(:user) }
    let(:current_sp) { create(:service_provider) }

    before do
      stub_sign_in(user)
      subject.session[:sp] = {
        issuer: current_sp.issuer,
        acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        requested_attributes: [:email],
        request_url: 'http://localhost:3000',
      }
    end

    it 'renders the show view with a link back to continue SP consent' do
      get :show

      expect(controller.pending_completions_consent?).to eq(:new_sp)
    end
  end

  describe '#limit' do
    context 'user exceeds email limit' do
      let(:user) { create(:user) }
      before do
        stub_sign_in(user)

        while EmailPolicy.new(user).can_add_email?
          email = Faker::Internet.email
          user.email_addresses.create(email: email, confirmed_at: Time.zone.now)
        end
      end
      it 'displays error if email exceeds limit' do
        controller.request.headers.merge({ HTTP_REFERER: account_url })

        get :show
        expect(response).to redirect_to(account_url(anchor: 'emails'))
        expect(response.request.flash[:email_error]).to_not be_nil
      end
    end
  end

  describe '#resend' do
    let(:user) { create(:user) }
    before do
      stub_sign_in(user)
      stub_analytics
    end

    context 'valid email exists in session' do
      it 'sends email' do
        email = Faker::Internet.email

        post :add, params: { user: { email: email } }

        expect(@analytics).to have_logged_event(
          'Add Email Requested',
          success: true,
          errors: {},
          user_id: user.uuid,
          domain_name: email.split('@').last,
        )

        post :resend

        expect(@analytics).to have_logged_event(
          'Resend Add Email Requested',
          { success: true },
        )
        expect(last_email_sent).to have_subject(
          t('user_mailer.email_confirmation_instructions.subject'),
        )

        expect(response).to redirect_to(add_email_verify_email_url)
        expect(last_email_sent).to have_subject(
          t('user_mailer.email_confirmation_instructions.subject'),
        )
        expect(ActionMailer::Base.deliveries.count).to eq 2
      end
    end

    context 'no valid email exists in session' do
      it 'shows an error and redirects to add email page' do
        post :resend

        expect(@analytics).to have_logged_event(
          'Resend Add Email Requested',
          { success: false },
        )
        expect(flash[:error]).to eq t('errors.general')
        expect(response).to redirect_to(add_email_url)
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end
  end
end
