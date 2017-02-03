require 'rails_helper'

describe UsersController do
  it 'destroys the current user and redirect to the sign in page' do
    sign_in_as_user

    delete :destroy

    expect(flash[:now]).to eq t('users.delete')
    expect(subject.current_user).not_to be_present
    expect(response).to redirect_to(root_url)
  end

  xit 'redirects to the root path'
  xit 'populates the success flash with a message'
end
