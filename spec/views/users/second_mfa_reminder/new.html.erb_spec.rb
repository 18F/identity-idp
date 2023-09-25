require 'rails_helper'

RSpec.describe 'users/second_mfa_reminder/new.html.erb' do
  subject(:rendered) { render }

  let(:sp_name) {}

  before do
    decorated_sp_session = double
    allow(decorated_sp_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
  end

  it 'renders with fallback app name for continue button' do
    expect(rendered).to have_button(t('users.second_mfa_reminder.continue', sp_name: APP_NAME))
  end

  context 'with sp name' do
    let(:sp_name) { 'Example SP' }

    it 'renders with sp name for continue button' do
      expect(rendered).to have_button(t('users.second_mfa_reminder.continue', sp_name:))
    end
  end
end
