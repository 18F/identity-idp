require 'rails_helper'

RSpec.describe Users::RulesOfUseController do
  let(:rules_of_use_updated_at) { 1.day.ago }
  let(:accepted_terms_at) { nil }
  let(:user) { create(:user, :signed_up, accepted_terms_at: accepted_terms_at) }
  before do
    allow(IdentityConfig.store).to receive(:rules_of_use_updated_at).
      and_return(rules_of_use_updated_at)
  end
  describe 'before_actions' do
    it 'includes appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_signed_in,
        :confirm_need_to_accept_rules_of_use,
      )
    end
  end

  describe '#new' do
    subject(:action) { get :new }

    context 'with a user that has not accepted the rules of use' do
      before do
        sign_in_before_2fa(user)
      end

      it 'renders' do
        action
        expect(response).to render_template(:new)
      end

      it 'logs an analytics event for visiting' do
        stub_analytics
        expect(@analytics).to receive(:track_event).with('Rules of Use Visited')

        action
      end
    end

    context 'with a user that has accepted the rules of use' do
      before do
        sign_in_before_2fa
      end

      it 'redirects to mfa' do
        action

        expect(response).to redirect_to user_two_factor_authentication_url
      end
    end

    context 'with a user who is not up to date with rules of use ' do
      let(:accepted_terms_at) { 2.days.ago }
      before do
        sign_in_before_2fa(user)
      end

      it 'renders' do
        action
        expect(response).to render_template(:new)
      end

      it 'logs an analytics event for visiting' do
        stub_analytics
        expect(@analytics).to receive(:track_event).with('Rules of Use Visited')

        action
      end
    end

    context 'with a user who is up to date with rules of use' do
      let(:accepted_terms_at) { 12.hours.ago }
      before do
        sign_in_before_2fa(user)
      end

      it 'redirects to mfa' do
        action

        expect(response).to redirect_to user_two_factor_authentication_url
      end
    end

    context 'with no user signed in' do
      it 'redirects to root' do
        action

        expect(response).to redirect_to root_url
      end
    end
  end

  describe '#create' do
    context 'when the user needs to accept the rules of use and does accept them' do
      subject(:action) do
        post :create, params: { rules_of_use_form: { terms_accepted: '1' } }
      end

      before do
        sign_in_before_2fa(user)
      end

      it 'updates the user accepted terms at timestamp' do
        action

        expect(controller.current_user.reload.accepted_terms_at).to be_present
      end

      it 'redirects to the two factor authentication page' do
        action

        expect(response).to redirect_to user_two_factor_authentication_url
      end

      it 'logs a successful analytics event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with('Rules of Use Submitted', hash_including(success: true))

        action
      end
    end

    context 'when the user needs to accept the rules of use and does not accept them' do
      subject(:action) do
        post :create, params: { rules_of_use_form: { terms_accepted: '0' } }
      end

      before do
        sign_in_before_2fa(user)
      end

      it 'does not updates the user accepted terms at timestamp' do
        action

        expect(controller.current_user.reload.accepted_terms_at).to be_nil
      end

      it 'redirects to the two factor authentication page' do
        action

        expect(response).to render_template(:new)
      end

      it 'logs a failure analytics event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
            with('Rules of Use Submitted', hash_including(success: false))

        action
      end
    end
  end
end
