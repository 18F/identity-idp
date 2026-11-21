require 'rails_helper'

RSpec.describe 'users/emails/confirm_delete.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_multiple_emails) }
  let(:email_address) { user.email_addresses.last }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    controller.params[:id] = email_address.id
    assign(:presenter, ConfirmDeleteEmailPresenter.new(user, email_address))
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.confirmations.delete'))

    render
  end

  it 'renders the legacy confirmation with a delete button and cancel link' do
    render

    expect(rendered).to have_css(
      'h1',
      text: t('email_addresses.delete.confirm', email: email_address.email),
    )
    expect(rendered).to have_button(t('forms.email.buttons.delete'))
    expect(rendered).to have_link(t('links.cancel'), href: account_path)
  end

  it 'does not render the NDS form page in the default layout' do
    render

    expect(rendered).to_not have_css('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the heading and the consequences in the signed-in header layout' do
      render

      expect(view.content_for(:nds_account_header)).to eq('true')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('nds.dashboard_account.delete_email_heading', email: email_address.email),
      )
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('nds.dashboard_account.delete_email_info', app_name: APP_NAME),
      )
      expect(rendered).to_not have_content(t('email_addresses.delete.warning'))
    end

    it 'deletes the email with a destructive button and cancels to the account page' do
      render

      expect(rendered).to have_css(
        ".auth__actions form[action='#{delete_email_url(id: email_address.id)}'] " \
          "input[name=_method][value=delete]",
        visible: :all,
      )
      expect(rendered).to have_css(
        '.auth__actions form button.usa-button--danger',
        text: t('forms.email.buttons.delete'),
      )
      expect(rendered).to have_link(
        t('links.cancel'),
        href: account_path,
        class: 'usa-button--tertiary',
      )
    end
  end
end
