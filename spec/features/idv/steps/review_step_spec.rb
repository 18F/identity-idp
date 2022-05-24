require 'rails_helper'

feature 'idv review step' do
  include IdvStepHelper

  it 'routes to root if not signed in' do
    visit idv_review_path

    expect(current_path).to eq(root_path)
  end

  it 'requires the user to enter the correct password to redirect to confirmation step', js: true do
    start_idv_from_sp
    complete_idv_steps_before_review_step

    click_on t('idv.messages.review.intro')

    expect(page).to have_content('FAKEY')
    expect(page).to have_content('MCFAKERSON')
    expect(page).to have_content('1 FAKE RD')
    expect(page).to have_content('GREAT FALLS, MT 59010')
    expect(page).to have_content('October 06, 1938')
    expect(page).to have_content(DocAuthHelper::GOOD_SSN)
    expect(page).to have_content('+1 202-555-1212')

    fill_in 'Password', with: 'this is not the right password'
    click_idv_continue

    expect(page).to have_content(t('idv.errors.incorrect_password'))
    expect(page).to have_current_path(idv_review_path)

    fill_in 'Password', with: user_password
    click_idv_continue

    expect(page).to have_content(t('headings.personal_key'))
    expect(current_path).to be_in([idv_personal_key_path, idv_app_path])
  end

  context 'choosing to confirm address with phone' do
    let(:user) { user_with_2fa }

    before do
      start_idv_from_sp
      complete_idv_steps_with_phone_before_review_step(user)
    end

    it 'does not send a letter and creates a verified profile' do
      fill_in 'Password', with: user_password
      click_idv_continue

      expect(user.events.account_verified.size).to be(1)
      expect(user.profiles.count).to eq 1

      profile = user.profiles.first

      expect(profile.active?).to eq true
      expect(GpoConfirmation.count).to eq(0)
    end
  end

  context 'choosing to confirm address with gpo' do
    let(:user) { user_with_2fa }
    let(:sp) { :oidc }

    before do
      start_idv_from_sp(sp)
      complete_idv_steps_with_gpo_before_review_step(user)
    end

    it 'sends a letter and creates an unverified profile' do
      fill_in 'Password', with: user_password

      expect { click_continue }.
        to change { GpoConfirmation.count }.from(0).to(1)

      expect(user.events.account_verified.size).to be(0)
      expect(user.profiles.count).to eq 1

      profile = user.profiles.first

      expect(profile.active?).to eq false
    end

    context 'with an sp' do
      it 'sends a letter with a reference the sp' do
        fill_in 'Password', with: user_password
        click_continue

        gpo_confirmation_entry = GpoConfirmation.last.entry

        if sp == :saml
          expect(gpo_confirmation_entry[:issuer]).
            to eq(sp1_issuer)
        else
          expect(gpo_confirmation_entry[:issuer]).
            to eq('urn:gov:gsa:openidconnect:sp:server')
        end
      end
    end

    context 'without an sp' do
      let(:sp) { nil }

      it 'sends a letter without a reference to the sp' do
        fill_in 'Password', with: user_password
        click_continue

        gpo_confirmation_entry = GpoConfirmation.last.entry

        expect(gpo_confirmation_entry[:issuer]).to eq(nil)
      end
    end
  end

  context 'with idv app feature enabled', js: true do
    before do
      allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).
        and_return(['password_confirm', 'personal_key', 'personal_key_confirm'])
    end

    it 'redirects to personal key step after user enters their password', allow_browser_log: true do
      start_idv_from_sp
      complete_idv_steps_before_review_step

      click_on t('idv.messages.review.intro')

      expect(page).to have_content('FAKEY')
      expect(page).to have_content('MCFAKERSON')
      expect(page).to have_content('1 FAKE RD')
      expect(page).to have_content('GREAT FALLS, MT 59010')
      expect(page).to have_content('October 6, 1938')
      expect(page).to have_content(DocAuthHelper::GOOD_SSN)
      expect(page).to have_content('(202) 555-1212')

      fill_in t('components.password_toggle.label'), with: 'this is not the right password'
      click_idv_continue

      expect(page).to have_content(t('idv.errors.incorrect_password'))
      expect(page).to have_current_path(idv_app_path(step: :password_confirm))

      fill_in t('components.password_toggle.label'), with: user_password
      click_idv_continue

      expect(page).to have_content(t('headings.personal_key'))
      expect(page).to have_current_path(idv_app_path(step: :personal_key))
    end
  end

  context 'cancelling IdV' do
    it_behaves_like 'cancel at idv step', :review
    it_behaves_like 'cancel at idv step', :review, :oidc
  end
end
