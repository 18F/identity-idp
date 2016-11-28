require 'rails_helper'

describe 'users/confirmations/show.html.slim' do
  before do
    user = build_stubbed(:user, :signed_up)
    @password_form = PasswordForm.new(user)
  end

  it 'displays the correct progress step' do
    render

    expect(rendered).to have_css('.step-2.active')
  end
end
