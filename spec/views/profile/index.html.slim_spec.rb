require 'rails_helper'

describe 'profile/index.html.slim' do
  let(:user) { build_stubbed(:user, :signed_up) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:view_model, ProfileIndex.new(decrypted_pii: nil, personal_key: nil, current_user: user))
  end

  context 'user is not TOTP enabled' do
    it 'has a localized title' do
      expect(view).to receive(:title).with(t('titles.profile'))

      render
    end

    it 'contains link to enable TOTP' do
      render

      expect(rendered).to have_link('Enable', href: authenticator_start_url)
      expect(rendered).not_to have_xpath("//input[@value='Disable']")
    end

    xit 'contains link to delete account' do
      pending 'temporarily disabled until we figure out the MBUN to SSN mapping'
      render

      expect(rendered).to have_content t('headings.delete_account', app: APP_NAME)
      expect(rendered).
        to have_xpath("//input[@value='#{t('forms.buttons.delete_account')}']")
    end
  end

  context 'when user is TOTP enabled' do
    let(:user) { build_stubbed(:user, :signed_up, otp_secret_key: '123') }

    before do
      assign(
        :view_model,
        ProfileIndex.new(decrypted_pii: nil, personal_key: nil, current_user: user)
      )
    end

    it 'contains link to disable TOTP' do
      render

      expect(rendered).to have_button t('forms.buttons.disable')
      expect(rendered).not_to have_link(t('forms.buttons.enable'), href: authenticator_start_path)
    end
  end

  context 'when the user does not have password_reset_profile' do
    before do
      allow(view).to receive(:current_user).and_return(user)
      allow(user).to receive(:password_reset_profile).and_return(false)
    end

    it 'contains a personal key section' do
      render

      expect(rendered).to have_content t('profile.items.personal_key')
      expect(rendered).
        to have_link(t('profile.links.regenerate_personal_key'), href: manage_personal_key_path)
    end
  end

  context 'when current user has password_reset_profile' do
    before do
      allow(view).to receive(:current_user).and_return(user)
      allow(user).to receive(:password_reset_profile).and_return(true)
    end

    it 'lacks a personal key section' do
      render

      expect(rendered).to_not have_content t('profile.items.personal_key')
      expect(rendered).to_not have_link(
        t('profile.links.regenerate_personal_key'), href: manage_personal_key_path
      )
    end
  end

  it 'contains account history' do
    render

    expect(rendered).to have_content t('headings.profile.account_history')
  end

  it 'shows the auth nav bar' do
    render

    expect(view).to render_template(partial: '_nav_auth')
  end
end
