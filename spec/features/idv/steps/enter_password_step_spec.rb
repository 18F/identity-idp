require 'rails_helper'

RSpec.feature 'idv enter password step', :js do
  include IdvStepHelper

  context 'choosing to confirm address with gpo' do
    let(:user) { user_with_2fa }
    let(:sp) { :oidc }

    before do
      start_idv_from_sp(sp)
      complete_idv_steps_with_gpo_before_enter_password_step(user)
    end

    it 'sends a letter, creates an unverified profile, and sends an email' do
      sends_letter_creates_unverified_profile_sends_email
    end

    context 'user is rate-limited' do
      before do
        RateLimiter.new(user:, rate_limit_type: :proof_address).increment_to_limited!
      end

      it 'sends a letter, creates an unverified profile, and sends an email' do
        sends_letter_creates_unverified_profile_sends_email
      end
    end

    it 'sends you to the come_back_later page after enter password step' do
      fill_in 'Password', with: user_password
      click_continue

      expect(page).to have_content(t('idv.titles.come_back_later'))
      expect(current_path).to eq idv_letter_enqueued_path
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

    def sends_letter_creates_unverified_profile_sends_email
      fill_in 'Password', with: user_password

      email_count_before_continue = ActionMailer::Base.deliveries.count

      expect { click_continue }.
        to change { GpoConfirmation.count }.by(1)

      expect_delivered_email_count(email_count_before_continue + 1)
      expect(last_email.subject).to eq(t('user_mailer.letter_reminder.subject'))

      expect(user.events.account_verified.size).to be(0)
      expect(user.profiles.count).to eq 1

      profile = user.profiles.first

      expect(profile.active?).to eq false
    end
  end

  context 'user has attempted to redo document capture after completing verify info' do
    let(:user) { user_with_2fa }

    before do
      start_idv_from_sp
      complete_idv_steps_with_phone_before_enter_password_step(user)
    end

    it 'allows the user to submit password and proceed to obtain a personal key' do
      visit(idv_hybrid_handoff_url(redo: true))
      complete_enter_password_step(user)
      expect(current_path).to eq idv_personal_key_path
    end
  end
end
