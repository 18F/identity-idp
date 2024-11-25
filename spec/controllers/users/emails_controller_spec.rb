require 'rails_helper'

RSpec.describe Users::EmailsController do
  describe '#show' do
    subject(:response) { get :show, params: params }
    let(:params) { {} }

    before do
      stub_sign_in
    end

    it 'does not session value for email selection flow' do
      expect { response }.not_to change { controller.session[:in_select_email_flow] }.from(nil)
    end

    it 'logs visit' do
      stub_analytics

      response

      expect(@analytics).to have_logged_event(
        'Add Email Address Page Visited',
        in_select_email_flow: false,
      )
    end

    context 'when adding through partner email selection flow' do
      let(:params) { { in_select_email_flow: true } }

      it 'assigns session value for email selection flow' do
        expect { response }.to change { controller.session[:in_select_email_flow] }.
          from(nil).to(true)
      end

      it 'logs visit with selected email value' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          'Add Email Address Page Visited',
          in_select_email_flow: true,
        )
      end
    end
  end

  describe '#add' do
    subject(:response) { post :add, params: params }
    let(:user) { create(:user) }
    let(:params) { { user: { email:, request_id: } } }
    let(:email) { 'new@example.com' }
    let(:request_id) { 'request-id-1' }

    before do
      stub_sign_in(user)
    end

    it 'logs submission' do
      stub_analytics

      response

      expect(@analytics).to have_logged_event(
        'Add Email Requested',
        success: true,
        errors: {},
        domain_name: 'example.com',
        in_select_email_flow: false,
        user_id: user.uuid,
      )
    end

    context 'when adding through partner email selection flow' do
      before do
        controller.session[:in_select_email_flow] = true
      end

      it 'logs submission with selected email value' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          'Add Email Requested',
          hash_including(in_select_email_flow: true),
        )
      end
    end
  end

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

      expect(@analytics).to have_logged_event(
        'Add Email Address Page Visited',
        in_select_email_flow: false,
      )
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

    it 'sets the pending completions consent value to true' do
      get :show

      expect(controller.pending_completions_consent?).to eq(true)
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
          in_select_email_flow: false,
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

  describe '#delete' do
    subject(:response) { delete :delete, params: params }
    let(:user) { create(:user, :fully_registered, :with_multiple_emails) }
    let(:params) { { id: user.email_addresses.take.id } }

    before do
      stub_sign_in(user)
    end

    it 'redirects to account page' do
      expect(response).to redirect_to(account_url)
    end

    context 'with invalid submisson' do
      let(:user) { create(:user, :fully_registered) }

      it 'logs analytics' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          'Email Deletion Requested',
          success: false,
          errors: {},
        )
      end

      it 'flashes error' do
        response

        expect(flash[:error]).to eq(t('email_addresses.delete.failure'))
      end
    end

    context 'with valid submission' do
      it 'logs analytics' do
        stub_analytics

        response

        expect(@analytics).to have_logged_event(
          'Email Deletion Requested',
          success: true,
          errors: {},
        )
      end

      it 'notifies all confirmed email addresses, including the deleted' do
        email_addresses = user.confirmed_email_addresses.to_a

        response

        expect_delivered_email_count(email_addresses.count)
        email_addresses.each do |email_address|
          expect_delivered_email(
            to: [email_address.email],
            subject: t('user_mailer.email_deleted.subject'),
          )
        end
      end

      it 'flashes success' do
        response

        expect(flash[:success]).to eq(t('email_addresses.delete.success'))
      end

      it 'tracks user event' do
        expect { response }.to change { user.events.count }.by(1)
        expect(user.events.last.event_type).to eq('email_deleted')
      end

      it 'deletes the email address' do
        expect { response }.to change { user.email_addresses.count }.by(-1)
      end

      context 'with selected email for linked identity in session' do
        before do
          controller.user_session[:selected_email_id_for_linked_identity] = params[:id]
        end

        it 'resets session value' do
          response

          expect(controller.user_session[:selected_email_id_for_linked_identity]).to be_nil
        end
      end
    end
  end
end
