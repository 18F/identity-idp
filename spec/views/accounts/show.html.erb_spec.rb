require 'rails_helper'

describe 'accounts/show.html.erb' do
  let(:user) { create(:user, :signed_up) }
  let(:decorated_user) { user.decorate }

  before do
    allow(user).to receive(:decorate).and_return(decorated_user)
    allow(view).to receive(:current_user).and_return(user)
    assign(
      :view_model,
      AccountShow.new(decrypted_pii: nil, personal_key: nil, decorated_user: decorated_user),
    )
  end

  context 'user is not TOTP enabled' do
    it 'has a localized title' do
      expect(view).to receive(:title).with(t('titles.account'))

      render
    end

    it 'contains link to enable TOTP' do
      render

      expect(rendered).to have_link('Enable', href: authenticator_setup_url)
      expect(rendered).not_to have_xpath("//input[@value='Disable']")
    end

    it 'contains link to delete account' do
      render

      expect(rendered).to have_content t('account.items.delete_your_account', app: APP_NAME)
      expect(rendered).
        to have_link(t('account.links.delete_account'), href: account_delete_path)
    end
  end

  context 'when user is TOTP enabled' do
    let(:user) { create(:user, :signed_up, otp_secret_key: '123') }

    before do
      assign(
        :view_model,
        AccountShow.new(decrypted_pii: nil, personal_key: nil, decorated_user: decorated_user),
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
      allow(decorated_user).to receive(:password_reset_profile).and_return(false)
    end

    it 'contains a personal key section' do
      render

      expect(rendered).to have_content t('account.items.personal_key')
      expect(rendered).
        to have_button t('account.links.regenerate_personal_key')
      expect(rendered).to have_xpath("//form[@action='#{create_new_personal_key_url}']")
    end
  end

  context 'when current user has password_reset_profile' do
    before do
      allow(decorated_user).to receive(:password_reset_profile).and_return(true)
    end

    it 'lacks a personal key section' do
      render

      expect(rendered).to_not have_content t('account.items.personal_key')
      expect(rendered).to_not have_link(
        t('account.links.regenerate_personal_key'), href: manage_personal_key_path
      )
    end

    it 'displays an alert with instructions to reactivate their profile' do
      render

      expect(rendered).to have_content(t('account.index.reactivation.instructions'))
    end

    it 'contains link to reactivate profile via personal key or reverification' do
      render

      expect(rendered).to have_link(t('account.index.reactivation.link'),
                                    href: reactivate_account_path)
    end
  end

  context 'when the user does not have pending_profile' do
    before do
      allow(decorated_user).to receive(:pending_profile).and_return(false)
    end

    it 'lacks a pending profile section' do
      render

      expect(rendered).to_not have_link(
        t('account.index.verification.reactivate_button'), href: verify_account_path
      )
    end
  end

  context 'when current user has pending_profile' do
    before do
      allow(decorated_user).to receive(:pending_profile).and_return(build(:profile))
    end

    it 'contains a link to activate profile' do
      render

      expect(rendered).
        to have_link(t('account.index.verification.reactivate_button'), href: verify_account_path)
    end
  end

  it 'contains account history' do
    render

    expect(rendered).to have_content t('headings.account.account_history')
  end

  it 'contains connected applications' do
    render

    expect(rendered).to have_content t('headings.account.connected_apps')
  end

  it 'shows the auth nav bar' do
    render

    expect(view).to render_template(partial: '_nav_auth')
  end

  it 'shows the delete account bar' do
    render

    expect(view).to render_template(partial: '_delete_account_item_heading')
  end

  context 'phone listing and adding' do
    it 'renders the phone section' do
      render

      expect(view).to render_template(partial: '_phone')
    end

    context 'user has no phone' do
      let(:user) do
        record = create(:user, :signed_up, :with_piv_or_cac)
        record.phone_configurations = []
        record
      end

      it 'shows the add phone link' do
        render

        expect(rendered).to have_link(
          t('account.index.phone_add'), href: add_phone_path
        )
      end
    end

    context 'user has a phone' do
      it 'shows add phone link' do
        render

        expect(rendered).to have_content t('account.index.phone_add')
        expect(rendered).to have_link(
          t('account.index.phone_add'), href: add_phone_path
        )
      end

      it 'shows an edit link' do
        render

        expect(rendered).to have_link(
          t('account.index.phone'), href: manage_phone_url(id: user.phone_configurations.first.id)
        )
      end
    end
  end

  context 'email listing and adding' do
    let(:user) do
      record = create(:user)
      record
    end

    it 'renders the email section' do
      render

      expect(view).to render_template(partial: '_emails')
    end

    it 'shows one email if the user has only one email' do
      expect(user.email_addresses.size).to eq(1)
    end

    it 'shows one email if the user has only one email' do
      create_list(:email_address, 4, user: user)
      user.reload
      expect(user.email_addresses.size).to eq(5)
    end
  end
end
