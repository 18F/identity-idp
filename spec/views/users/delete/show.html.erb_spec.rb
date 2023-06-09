require 'rails_helper'

RSpec.describe 'users/delete/show.html.erb' do
  let(:user) { build_stubbed(:user, :fully_registered) }

  before do
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'displays headings' do
    render

    expect(rendered).to have_content(t('users.delete.heading', app_name: APP_NAME))
    expect(rendered).to have_content(t('users.delete.subheading', app_name: APP_NAME))
  end

  it 'displays bullets' do
    render

    expect(rendered).to have_content(t('users.delete.bullet_1', app_name: APP_NAME))
    expect(rendered).to have_content(user.delete_account_bullet_key)
    expect(rendered).to have_content(t('users.delete.bullet_3', app_name: APP_NAME))
    expect(rendered).to have_content(t('users.delete.bullet_4', app_name: APP_NAME))
  end

  it 'displays bullets for loa1' do
    allow(user).to receive(:identity_verified?).and_return(false)
    expect(user.delete_account_bullet_key).
      to eq t('users.delete.bullet_2_basic', app_name: APP_NAME)
  end

  it 'displays bullets for loa1' do
    allow(user).to receive(:identity_verified?).and_return(true)
    expect(user.delete_account_bullet_key).
      to eq t('users.delete.bullet_2_verified', app_name: APP_NAME)
  end

  it 'contains link to delete account button' do
    render

    expect(rendered).to have_css("form[action='#{account_delete_path}']")
    expect(rendered).to have_button(t('users.delete.actions.delete'))
  end

  it 'contains link to cancel delete account link' do
    render

    expect(rendered).to have_link(t('users.delete.actions.cancel'), href: account_path)
  end
end
