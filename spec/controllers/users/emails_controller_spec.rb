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

  describe '#limit' do
    context 'user exceeds email limit' do
      let(:user) { create(:user) }
      before do
        stub_sign_in(user)

        while EmailPolicy.new(user).can_add_email?
          email = Faker::Internet.safe_email
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
end
