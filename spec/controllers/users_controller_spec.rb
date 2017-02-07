require 'rails_helper'

describe UsersController do
  before do
    sign_in_as_user
  end

  it 'destroys the current user and redirect to the sign in page' do
    expect do
      delete :destroy
    end.to change(User, :count).by(-1)
  end

  it 'redirects to the root path' do
    delete :destroy

    expect(response).to redirect_to(root_url)
  end

  it 'populates the success flash with a message' do
    delete :destroy
    expect(flash.now[:success]).to eq t('loa1.cancel.success')
  end
end
