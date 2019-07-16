require 'rails_helper'

describe 'account_reset/request/show.html.slim' do
  before do
    user = create(:user, :signed_up)
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('account_reset.request.title'))

    render
  end

  it 'has button to delete' do
    render
    expect(rendered).to have_button t('account_reset.request.yes_continue')
  end

  it 'shows personal key info when a user has a personal key' do
    render
    expect(rendered).to have_content(t('account_reset.request.personal_key'))
  end

  it 'does not show personal key info when a user does not have a personal key' do
    user = view.current_user
    user.encrypted_recovery_code_digest = ''
    user.save

    render
    expect(rendered).to_not have_content(t('account_reset.request.personal_key'))
  end
end
