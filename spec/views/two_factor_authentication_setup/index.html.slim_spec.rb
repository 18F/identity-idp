require 'rails_helper'

describe 'users/two_factor_authentication_setup/index.html.slim' do
  include DecoratedSessionHelper

  let(:sp_name) { '🔒🌐💻' }

  before do
    user = build_stubbed(:user)

    allow(view).to receive(:current_user).and_return(user)

    @user_phone_form = UserPhoneForm.new(user)

    allow(view).to receive(:decorated_session).and_return(decorated_session)
    allow(decorated_session).to receive(:sp_name).and_return(sp_name)

    render
  end

  it 'sets form autocomplete to off' do
    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end
end
