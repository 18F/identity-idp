require 'rails_helper'

describe 'accounts/show.html.erb' do
  let(:user) { create(:user, :signed_up, :with_personal_key) }
  let(:decorated_user) { user.decorate }

  before do
    allow(user).to receive(:decorate).and_return(decorated_user)
    allow(view).to receive(:current_user).and_return(user)
    assign(
      :presenter,
      AccountShowPresenter.new(
        decrypted_pii: nil, personal_key: nil, decorated_user: decorated_user,
        sp_session_request_url: nil, sp_name: nil,
        locked_for_session: false
      ),
    )
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.account'))

    render
  end

  context 'when current user has password_reset_profile' do
    before do
      allow(decorated_user).to receive(:password_reset_profile).and_return(true)
    end

    it 'displays an alert with instructions to reactivate their profile' do
      render

      expect(rendered).to have_content(t('account.index.reactivation.instructions'))
    end

    it 'contains link to reactivate profile via personal key or reverification' do
      render

      expect(rendered).to have_link(
        t('account.index.reactivation.link'),
        href: reactivate_account_path,
      )
    end
  end

  context 'when the user does not have pending_profile' do
    before do
      allow(decorated_user).to receive(:pending_profile).and_return(false)
    end

    it 'lacks a pending profile section' do
      render

      expect(rendered).to_not have_link(
        t('account.index.verification.reactivate_button'), href: idv_gpo_verify_path
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
        to have_link(t('account.index.verification.reactivate_button'), href: idv_gpo_verify_path)
    end
  end

  context 'phone listing and adding' do
    context 'user has no phone' do
      let(:user) do
        record = create(:user, :signed_up, :with_piv_or_cac)
        record.phone_configurations = []
        record
      end

      it 'does not render phone' do
        expect(view).to_not render_template(partial: '_phone')
      end
    end

    context 'user has a phone' do
      it 'renders the phone section' do
        render

        expect(view).to render_template(partial: '_phone')
      end

      it 'formats phone numbers' do
        user.phone_configurations.first.tap do |phone_configuration|
          phone_configuration.phone = '+18888675309'
          phone_configuration.save
        end
        render
        expect(rendered).to have_selector('.grid-col-fill', text: '+1 888-867-5309')
      end
    end
  end

  context 'auth app listing and adding' do
    context 'user has no auth app' do
      let(:user) { create(:user, :signed_up, :with_piv_or_cac) }

      it 'does not render auth app' do
        expect(view).to_not render_template(partial: '_auth_apps')
      end
    end

    context 'user has an auth app' do
      let(:user) { create(:user, :signed_up, :with_authentication_app) }
      it 'renders the auth app section' do
        render

        expect(view).to render_template(partial: '_auth_apps')
      end
    end
  end

  context 'PIV/CAC listing and adding' do
    context 'user has no piv/cac' do
      let(:user) { create(:user, :signed_up, :with_authentication_app) }

      it 'does not render piv/cac' do
        expect(view).to_not render_template(partial: '_piv_cac')
      end
    end

    context 'user has a piv/cac' do
      let(:user) { create(:user, :signed_up, :with_piv_or_cac) }
      it 'renders the piv/cac section' do
        render

        expect(view).to render_template(partial: '_piv_cac')
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

  context 'when a profile has just been re-activated with personal key during SP auth' do
    let(:sp) { build(:service_provider, return_to_sp_url: 'https://www.example.com/auth') }
    before do
      assign(
        :presenter,
        AccountShowPresenter.new(
          decrypted_pii: nil, personal_key: 'abc123', decorated_user: decorated_user,
          sp_session_request_url: sp.return_to_sp_url, sp_name: sp.friendly_name,
          locked_for_session: false
        ),
      )
    end

    it 'renders the link to continue to the SP' do
      render

      expect(rendered).to have_link(
        t('account.index.continue_to_service_provider', service_provider: sp.friendly_name),
        href: sp.return_to_sp_url,
      )
    end
  end
end
