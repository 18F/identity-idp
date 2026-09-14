require 'rails_helper'

RSpec.describe 'users/delete/show.html.erb' do
  let(:user) { build_stubbed(:user, :fully_registered) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'does not render the NDS form-page card in the default layout' do
    render

    expect(rendered).to_not have_selector('.auth--form-page')
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
    expect(user.delete_account_bullet_key)
      .to eq t('users.delete.bullet_2_basic', app_name: APP_NAME)
  end

  it 'displays bullets for loa1' do
    allow(user).to receive(:identity_verified?).and_return(true)
    expect(user.delete_account_bullet_key)
      .to eq t('users.delete.bullet_2_verified', app_name: APP_NAME)
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

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the heading, subheading and bullets' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('.auth--form-page h1', text: t('users.delete.heading'))
      expect(rendered).to have_selector(
        '.auth__form-page-body .auth__intro-description',
        text: t('users.delete.subheading'),
      )
      expect(rendered).to have_css('.auth__form-page-body ul.list li', count: 4)
      expect(rendered).to have_content(user.delete_account_bullet_key)
    end

    it 'renders the floating-label password field inside the delete form' do
      render

      expect(rendered).to have_css("form[action='#{account_delete_path}'][method=post]")
      expect(rendered).to have_css(
        'form input.usa-input__control[type=password][name="user[password]"]' \
        '[autocomplete=current-password][required]',
      )
      expect(rendered).to have_css('label', text: t('idv.form.password'))
      expect(rendered).to have_css('button.usa-input__toggle[data-nds-password-toggle]')
      expect(rendered).to have_content(t('users.delete.instructions'))
    end

    it 'renders a destructive submit above a secondary cancel to the account page' do
      render

      expect(rendered).to have_css(
        '.auth__actions .actions button.usa-button.usa-button--danger[type=submit]',
        text: t('users.delete.actions.delete'),
      )
      expect(rendered).to have_css(
        ".auth__actions .actions a.usa-button--secondary[href='#{account_path}']",
        text: t('users.delete.actions.cancel'),
      )
    end
  end
end
