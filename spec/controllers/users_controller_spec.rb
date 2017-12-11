require 'rails_helper'

describe UsersController do
  describe '#destroy' do
    it 'redirects and displays the flash message if no user is present' do
      delete :destroy

      expect(response).to redirect_to(root_url)
      expect(flash.now[:success]).to eq t('sign_up.cancel.success')
    end

    it 'destroys the current user and redirects to sign in page, with a helpful flash message' do
      sign_in_as_user

      expect { delete :destroy }.to change(User, :count).by(-1)
      expect(response).to redirect_to(root_url)
      expect(flash.now[:success]).to eq t('sign_up.cancel.success')
    end

    it 'finds the proper user and removes their record without `current_user`' do
      confirmation_token = '1'

      create(:user, confirmation_token: confirmation_token)
      subject.session[:user_confirmation_token] = confirmation_token

      expect { delete :destroy }.to change(User, :count).by(-1)
    end

    it 'redirects to the branded start page if the user came from an SP' do
      session[:sp] = { issuer: 'http://localhost:3000', request_id: 'foo' }

      delete :destroy

      expect(response).
        to redirect_to sign_up_start_path(request_id: 'foo')
    end

    it 'tracks the event in analytics when referer is nil' do
      stub_analytics
      properties = { request_came_from: 'no referer' }

      expect(@analytics).to receive(:track_event).with(Analytics::ACCOUNT_DELETION, properties)

      delete :destroy
    end

    it 'tracks the event in analytics when referer is present' do
      stub_analytics
      request.env['HTTP_REFERER'] = 'http://example.com/'
      properties = { request_came_from: 'users/sessions#new' }

      expect(@analytics).to receive(:track_event).with(Analytics::ACCOUNT_DELETION, properties)

      delete :destroy
    end

    it 'calls ParseControllerFromReferer' do
      parser = instance_double(ParseControllerFromReferer)

      expect(ParseControllerFromReferer).to receive(:new).and_return(parser)
      expect(parser).to receive(:call)

      delete :destroy
    end
  end
end
