require 'rails_helper'

RSpec.describe 'idv/enter_password/new.html.erb' do
  include XPathHelper

  let(:nds_layout) { false }

  before { allow(view).to receive(:nds_layout?).and_return(nds_layout) }

  context 'user has completed all steps' do
    let(:dob) { '1972-03-29' }

    before do
      user = build_stubbed(:user, :fully_registered)
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:step_indicator_steps)
        .and_return(Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS)
      allow(view).to receive(:step_indicator_step).and_return(:re_enter_password)
    end

    context 'user goes through phone finder' do
      before do
        @title = t('titles.idv.enter_password')
        @heading = t('idv.titles.session.enter_password', app_name: APP_NAME)
        render
      end

      it 'has a localized title' do
        expect(view).to receive(:title=).with(t('titles.idv.enter_password'))

        render
      end

      it 'renders the correct content heading' do
        expect(rendered).to have_content t('idv.titles.session.enter_password', app_name: APP_NAME)
      end

      it 'shows the step indicator' do
        expect(view.content_for(:pre_flash_content)).to have_css(
          '.step-indicator__step--current',
          text: t('step_indicator.flows.idv.re_enter_password'),
        )
      end
    end

    context 'user goes through verify by mail flow' do
      before do
        @title = t('titles.idv.enter_password_letter')
        @heading = t('idv.titles.session.enter_password_letter', app_name: APP_NAME)
        render
      end

      it 'has a localized title' do
        expect(view).to receive(:title=).with(t('titles.idv.enter_password_letter'))

        render
      end

      it 'renders the correct content heading' do
        expect(rendered).to have_content(
          t('idv.titles.session.enter_password_letter', app_name: APP_NAME),
        )
      end
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }
    let(:verify_by_mail) { false }

    before do
      user = build_stubbed(:user, :fully_registered)
      allow(view).to receive(:current_user).and_return(user)
      @title = t('titles.idv.enter_password')
      @heading = t('idv.titles.session.enter_password', app_name: APP_NAME)
      @verify_by_mail = verify_by_mail
      render
    end

    it 'renders the password card with continue and a forgot-password action' do
      expect(rendered).to have_css('.auth--form-page h1', text: @heading)
      expect(rendered).to have_css('.auth__intro-description', text: t('nds.enter_password.info'))
      expect(rendered).to have_css('.usa-input__control--password[name="user[password]"]')
      expect(rendered).to have_css(
        '.auth__actions button[type=submit]',
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to have_link(
        t('idv.forgot_password.link_text'),
        href: idv_forgot_password_url,
      )
      expect(rendered).not_to have_css('#by-mail-password-warning')
    end

    it 'sets the verification header progress' do
      expect(view.content_for(:nds_header_progress)).to have_css(
        'nds-progress .progress__step[aria-current="step"]',
      )
    end

    context 'with a phone-verified flash' do
      before do
        flash[:success] = t('idv.messages.enter_password.phone_verified')
        render
      end

      it 'renders it as a toast' do
        expect(rendered).to have_css(
          'lg-toast.toast',
          text: t('idv.messages.enter_password.phone_verified'),
        )
      end
    end

    context 'when verifying by mail' do
      let(:verify_by_mail) { true }

      it 'shows the remember-your-password warning' do
        expect(rendered).to have_css('#by-mail-password-warning')
      end
    end
  end
end
