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

  it 'includes a link to create a new account' do
    render

    expect(rendered).
      to have_link(
        t('links.create_account'), href: new_user_start_path
      )
  end

  it 'includes a link to security / privacy page' do
    render

    expect(rendered).
      to have_link(t('notices.log_in_consent.link'), href: '#')
  end

  context 'when @sp_name is set' do
    before do
      @sp_name = 'Awesome Application!'
      @sp_return_url = 'www.awesomeness.com'
    end

    it 'displays a custom header' do
      render

      expect(rendered).to have_content(t('headings.log_in_branded',
                                         app: 'Awesome Application!'))
    end

    it 'displays a back to sp link' do
      render

      expect(rendered).
        to have_link(
          t('links.back_to_sp', app: 'Awesome Application!'), href: @sp_return_url
        )
    end
  end

  context 'when @sp_name is not set' do
    it 'displays the normal header' do
      render

      expect(rendered).to have_content(t('headings.log_in'))
    end
  end
end
