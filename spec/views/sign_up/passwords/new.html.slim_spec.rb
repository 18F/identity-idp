require 'rails_helper'

describe 'sign_up/passwords/new.html.slim' do
  before do
    user = build_stubbed(:user, :signed_up)
    @password_form = PasswordForm.new(user)
  end
end
