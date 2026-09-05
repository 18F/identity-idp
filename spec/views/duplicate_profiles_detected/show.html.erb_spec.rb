require 'rails_helper'

RSpec.describe 'duplicate_profiles_detected/show.html.erb' do
  let(:sp_name) { 'Veterans Affairs' }
  let(:decorated_sp_session) { double('DecoratedSpSession', sp_name:) }
  let(:associated_profiles) do
    [
      {
        email: 'john@example.com',
        masked_email: 'j****n@example.com',
        last_sign_in: nil,
        created_at: Time.zone.local(2025, 4, 15, 20, 18),
        connected_accts: 5,
        current_account: true,
      },
      {
        email: 'jane.doe@example.com',
        masked_email: 'j******e@example.com',
        last_sign_in: Time.zone.local(2026, 9, 2, 12, 0),
        created_at: Time.zone.local(2025, 4, 15, 20, 18),
        connected_accts: 5,
        current_account: false,
      },
    ]
  end
  let(:presenter) do
    instance_double(
      DuplicateProfilesDetectedPresenter,
      heading: t('duplicate_profiles_detected.heading'),
      associated_profiles:,
    )
  end

  before do
    allow(view).to receive(:duplicate_profiles_please_call_path) do |arg = nil, source: nil|
      duplicate_profiles_please_call_path(source: source || arg)
    end
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
    allow(view).to receive(:nds_layout?).and_return(false)
    @dupe_profiles_detected_presenter = presenter
  end

  it 'sets the page title to the heading' do
    expect(view).to receive(:title=).with(t('duplicate_profiles_detected.heading'))

    render
  end

  it 'renders the legacy status page in the default layout' do
    render

    expect(rendered).to have_selector('.usa-process-list')
    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the heading and intro' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page.duplicate-profiles')
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('duplicate_profiles_detected.heading'),
      )
      expect(rendered).to have_selector(
        '.auth__intro-description',
        text: sp_name,
      )
    end

    it 'renders the warning status icon' do
      render

      expect(rendered).to have_selector('.nds-status-icon.nds-status-icon--warning svg.usa-icon')
    end

    it 'renders the three-step process list' do
      render

      expect(rendered).to have_selector('ol.process-list .process-list__item', count: 3)
      expect(rendered).to have_selector(
        '.process-list__heading',
        text: t('nds.duplicate_profiles_detected.step_1.heading'),
      )
      expect(rendered).to have_link(
        t('nds.duplicate_profiles_detected.step_1.account_link'),
        href: account_path,
      )
    end

    it 'renders a card per associated profile with status badges' do
      render

      expect(rendered).to have_selector('.duplicate-profiles__account', count: 2)
      expect(rendered).to have_selector(
        '.badge--success',
        text: t('nds.duplicate_profiles_detected.signed_in'),
      )
      expect(rendered).to have_selector(
        '.badge--warning',
        text: t('nds.duplicate_profiles_detected.duplicate'),
      )
      expect(rendered).to have_content('john@example.com')
      expect(rendered).to have_content('j******e@example.com')
    end

    it 'renders the get-help, sign-out, and support actions' do
      render

      expect(rendered).to have_link(
        t('nds.duplicate_profiles_detected.get_help'),
        href: MarketingSite.help_center_article_url(
          category: 'manage-your-account',
          article: 'resolve-duplicate-accounts',
        ),
      )
      expect(rendered).to have_button(t('nds.duplicate_profiles_detected.sign_out'))
      expect(rendered).to have_link(
        t('nds.duplicate_profiles_detected.dont_recognize_account'),
        href: duplicate_profiles_please_call_path(source: 'dont_recognize'),
      )
      expect(rendered).to have_link(
        t('nds.duplicate_profiles_detected.cant_access'),
        href: duplicate_profiles_please_call_path(source: 'cant_access'),
      )
    end

    it 'shows the never-signed-in copy for a duplicate that never signed in' do
      associated_profiles[1][:last_sign_in] = nil

      render

      expect(rendered).to have_content(
        t('nds.duplicate_profiles_detected.never_signed_in', sp_name:),
      )
    end
  end
end
