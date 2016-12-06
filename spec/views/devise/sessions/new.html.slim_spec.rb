require 'rails_helper'

describe 'devise/sessions/new.html.slim' do
  before do
    allow(view).to receive(:resource).and_return(build_stubbed(:user))
    allow(view).to receive(:resource_name).and_return(:user)
    allow(view).to receive(:devise_mapping).and_return(Devise.mappings[:user])
    allow(view).to receive(:controller_name).and_return('sessions')
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.visitors.index'))

    render
  end

  it 'includes a link to log in' do
    render

    expect(rendered).to have_content(t('headings.sign_in_without_sp'))
  end

  it 'includes a link to create a new account' do
    render

    expect(rendered).
      to have_link(
        t('links.create_account'), href: sign_up_start_path
      )
  end

  it 'includes a link to security / privacy page' do
    render

    expect(rendered).
      to have_link(t('notices.sign_in_consent.link'), href: privacy_path)
  end

  context 'when @sp_name is set' do
    before do
      @sp_name = 'Awesome Application!'
      @sp_return_url = 'www.awesomeness.com'
    end

    it 'displays a custom header' do
      render

      expect(rendered).to have_content(
        t('headings.sign_in_with_sp', sp: 'Awesome Application!')
      )
    end

    it 'displays a back to sp link' do
      render

      expect(rendered).to have_link(
        t('links.back_to_sp', sp: 'Awesome Application!'), href: @sp_return_url
      )
    end
  end

  context 'when @sp_name is not set' do
    before do
      @sp_name = nil
    end

    it 'does not display the branded content' do
      render

      expect(rendered).not_to have_content(
        t('headings.sign_in_with_sp', sp: 'Awesome Application!')
      )
      expect(rendered).not_to have_link(
        t('links.back_to_sp', sp: 'Awesome Application!')
      )
    end
  end
end
