require 'rails_helper'

RSpec.describe 'idv/by_mail/sp_follow_up/new.html.erb' do
  let(:nds_layout) { false }
  let(:service_provider) { create(:service_provider, friendly_name: 'Test SP') }
  let(:user) do
    create(
      :profile,
      :active,
      initiating_service_provider: service_provider,
    ).user
  end
  let(:presenter) { Idv::ByMail::SpFollowUpPresenter.new(current_user: user) }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    @presenter = presenter

    render
  end

  it 'has a localized title' do
    expect(view.content_for(:title)).to eq(presenter.heading)
  end

  context 'in the default layout' do
    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end

    it 'renders the heading, body and actions' do
      expect(rendered).to have_css('h1', text: presenter.heading)
      expect(rendered).to have_content(presenter.body)
      expect(rendered).to have_link(
        t('idv.by_mail.sp_follow_up.connect_account'),
        href: idv_sp_follow_up_connect_path,
      )
      expect(rendered).to have_link(
        t('idv.by_mail.sp_follow_up.go_to_account'),
        href: idv_sp_follow_up_cancel_path,
      )
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the form-page card with the heading and body' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: presenter.heading)
      expect(rendered).to have_css('.auth__intro-description', text: presenter.body)
    end

    it 'renders the connect and go to account actions' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{idv_sp_follow_up_connect_path}']",
        text: t('idv.by_mail.sp_follow_up.connect_account'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{idv_sp_follow_up_cancel_path}']",
        text: t('idv.by_mail.sp_follow_up.go_to_account'),
      )
    end
  end
end
