require 'rails_helper'

RSpec.describe 'destructive_account_reset/delete_account/show.html.erb' do
  before do
    allow(view).to receive(:email).and_return('foo@bar.com')
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('destructive_account_reset.delete_account.title'))

    render
  end

  it 'has button to delete' do
    render
    expect(rendered).to have_button t('destructive_account_reset.request.yes_continue')
  end

  it 'does not render the NDS form-page card' do
    render
    expect(rendered).not_to have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    let(:update_cancel_account_reset_path) { true }

    before do
      allow(IdentityConfig.store).to receive(:update_cancel_account_reset_path)
        .and_return(update_cancel_account_reset_path)
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'renders the last resort heading and info' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro h1',
        text: t('destructive_account_reset.delete_account.title'),
      )
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('nds.destructive_account_reset.delete_account.info'),
      )
    end

    it 'renders a destructive primary action that deletes the account' do
      expect(rendered).to have_css(
        ".auth__actions form[action='#{account_reset_delete_account_path}'] " \
          "input[name='_method'][value='delete']",
        visible: :all,
      )
      expect(rendered).to have_css(
        ".auth__actions form[action='#{account_reset_delete_account_path}'] " \
          "button.usa-button--danger",
        text: t('destructive_account_reset.recover_options.yes_delete'),
      )
    end

    it 'renders the delete action before the cancel action' do
      expect(rendered.index(t('destructive_account_reset.recover_options.yes_delete')))
        .to be < rendered.index(t('nds.destructive_account_reset.pending.cancel_request'))
    end

    it 'posts the tertiary cancel action to the delete account cancel path' do
      expect(rendered).to have_css(
        ".auth__actions form[action='#{account_reset_delete_account_cancel_path}'] " \
          "button.usa-button--tertiary",
        text: t('nds.destructive_account_reset.pending.cancel_request'),
      )
    end

    context 'when the updated cancel path is disabled' do
      let(:update_cancel_account_reset_path) { false }

      it 'links the tertiary cancel action to the root url' do
        expect(rendered).to have_css(
          ".auth__actions a.usa-button--tertiary[href='#{root_url}']",
          text: t('nds.destructive_account_reset.pending.cancel_request'),
        )
        expect(rendered).not_to have_css(
          "form[action='#{account_reset_delete_account_cancel_path}']",
        )
      end
    end
  end
end
