require 'rails_helper'

RSpec.feature 'idv review step', :js do
  include IdvStepHelper

  context 'choosing to confirm address with gpo' do
    let(:user) { user_with_2fa }
    let(:sp) { :oidc }

    before do
      start_idv_from_sp(sp)
      complete_idv_steps_with_gpo_before_review_step(user)
    end

    it 'sends a letter, creates an unverified profile, and sends an email' do
      fill_in 'Password', with: user_password

      email_count_before_continue = ActionMailer::Base.deliveries.count

      expect { click_continue }.
        to change { GpoConfirmation.count }.from(0).to(1)

      expect_delivered_email_count(email_count_before_continue + 1)
      expect(last_email.subject).to eq(t('user_mailer.letter_reminder.subject'))

      expect(user.events.account_verified.size).to be(0)
      expect(user.profiles.count).to eq 1

      profile = user.profiles.first

      expect(profile.active?).to eq false
    end

    it 'sends you to the come_back_later page after review step' do
      fill_in 'Password', with: user_password
      click_continue

      expect(page).to have_content(t('idv.titles.come_back_later'))
      expect(current_path).to eq idv_come_back_later_path
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
end
