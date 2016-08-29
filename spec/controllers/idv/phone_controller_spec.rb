require 'rails_helper'
include Features::LocalizationHelper

describe Idv::PhoneController do
  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated
      )
    end
  end

  describe '#create' do
    context 'when form is invalid' do
      render_views

      it 'renders #new' do
        user = User.new(phone: '+1 (415) 555-0130')
        allow(subject).to receive(:confirm_two_factor_authenticated).and_return(true)
        allow(subject).to receive(:idv_session).and_return({})
        allow(subject).to receive(:current_user).and_return(user)

        put :create, idv_phone_form: { phone: '703' }

        expect(response.body).to have_content invalid_phone_message
        expect(subject.idv_session[:params]).to be_empty
      end
    end

    context 'when form is valid and submitted phone is same as user phone' do
      it 'redirects to review page and sets phone_confirmed_at' do
        user = User.new(phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now)
        allow(subject).to receive(:confirm_two_factor_authenticated).and_return(true)
        allow(subject).to receive(:idv_session).and_return({})
        allow(subject).to receive(:current_user).and_return(user)

        put :create, idv_phone_form: { phone: '+1 (415) 555-0130' }

        expect(response).to redirect_to idv_sessions_review_url

        hash = {
          phone: '+1 (415) 555-0130',
          phone_confirmed_at: user.phone_confirmed_at
        }
        expect(subject.idv_session[:params]).to eq hash
      end
    end

    context 'when form is valid and submitted phone is different from user phone' do
      it 'redirects to review page and does not set phone_confirmed_at' do
        user = User.new(phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now)
        allow(subject).to receive(:confirm_two_factor_authenticated).and_return(true)
        allow(subject).to receive(:idv_session).and_return({})
        allow(subject).to receive(:current_user).and_return(user)

        put :create, idv_phone_form: { phone: '+1 (415) 555-0160' }

        expect(response).to redirect_to idv_sessions_review_url

        hash = {
          phone: '+1 (415) 555-0160'
        }
        expect(subject.idv_session[:params]).to eq hash
      end
    end
  end
end
