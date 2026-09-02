require 'rails_helper'

RSpec.describe 'two_factor_authentication/otp_verification/show.html.erb' do
  include LinkHelper

  let(:presenter_data) do
    {
      otp_delivery_preference: 'sms',
      phone_number: '(***) ***-1212',
      code_value: '12777',
      unconfirmed_user: false,
    }
  end

  context 'user has a phone' do
    before do
      allow(view).to receive(:user_session).and_return({})
      allow(view).to receive(:nds_layout?).and_return(false)
      allow(view).to receive(:current_user).and_return(User.new)
      allow(view).to receive(:user_fully_authenticated?).and_return(false)
      controller.request.path_parameters[:otp_delivery_preference] =
        presenter_data[:otp_delivery_preference]

      @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(
        data: presenter_data,
        view: view,
        service_provider: nil,
      )
      allow(@presenter).to receive(:reauthn).and_return(false)
    end

    it 'allow user to return to two factor options screen' do
      render
      expect(rendered).to have_link(t('two_factor_authentication.choose_another_option'))
    end

    it 'does not show a landline setup warning' do
      render

      expect(rendered).not_to have_link(
        'phone call',
        href: phone_setup_path(otp_delivery_preference: 'voice'),
      )
    end

    context 'common OTP delivery screen behavior' do
      it 'has a localized title' do
        expect(view).to receive(:title=).with(t('titles.enter_2fa_code.one_time_code'))

        render
      end

      it 'has a localized heading' do
        render

        expect(rendered).to have_content t('two_factor_authentication.header_text')
      end
    end

    it 'informs the user that an OTP has been sent to their number' do
      render

      expect(rendered).to include(
        t(
          'instructions.mfa.sms.code_sent_message_html',
          number_html: content_tag(:strong, presenter_data[:phone_number]),
          expiration: TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_MINUTES,
        ),
      )
    end

    it 'informs the user to not share their OTP code' do
      render

      expect(rendered).to include(
        t(
          'instructions.mfa.do_not_share_code_message_html',
          link_html: new_tab_link_to(
            t('instructions.mfa.do_not_share_code_link_text'),
            MarketingSite.help_center_article_url(
              category: 'fraud-concerns',
              article: 'overview',
            ),
          ),
        ),
      )
    end

    context 'user signed up' do
      before do
        user = create(:user, :fully_registered, personal_key: '1')
        allow(view).to receive(:current_user).and_return(user)
        render
      end

      it 'provides an option to use a personal key' do
        expect(rendered).to have_link(
          t('two_factor_authentication.login_options_link_text'),
          href: login_two_factor_options_path,
        )
      end
    end

    context 'user is reauthenticating' do
      before do
        user = create(:user, :fully_registered, personal_key: '1')
        allow(view).to receive(:current_user).and_return(user)
        allow(@presenter).to receive(:reauthn).and_return(true)
        render
      end

      it 'provides a cancel link to return to profile' do
        expect(rendered).to have_link(
          t('links.cancel'),
          href: account_path,
        )
      end

      it 'renders the reauthn partial' do
        expect(view).to render_template(
          partial: 'two_factor_authentication/totp_verification/_reauthn',
        )
      end
    end

    context 'user is changing phone number' do
      it 'provides a cancel link to return to profile' do
        user = create(:user, :fully_registered, personal_key: '1')
        allow(view).to receive(:current_user).and_return(user)
        data = presenter_data.merge(confirmation_for_add_phone: true)
        @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(
          data: data,
          view: view,
          service_provider: nil,
        )

        render

        expect(rendered).to have_link(
          t('links.cancel'),
          href: account_path,
        )
      end
    end

    context 'when totp is enabled' do
      it 'allows user to sign in using an authenticator app' do
        totp_data = presenter_data.merge(totp_enabled: true)
        @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(
          data: totp_data,
          view: view,
          service_provider: nil,
        )

        render

        expect(rendered).to have_link(
          t('two_factor_authentication.login_options_link_text'),
          href: login_two_factor_options_path,
        )
      end
    end

    context 'when @code_value is set' do
      it 'pre-populates the form field' do
        render

        expect(rendered).to have_xpath("//input[@value='12777']")
      end
    end

    context 'when choosing to receive OTP via SMS' do
      let(:otp_delivery_preference) { 'sms' }

      it 'allows user to resend code using the same delivery method' do
        render

        resend_path = otp_send_path(
          otp_delivery_selection_form: {
            otp_delivery_preference: otp_delivery_preference,
            resend: true,
          },
        )

        expect(rendered).to have_link(
          t('links.two_factor_authentication.send_another_code'),
          href: resend_path,
        )
      end

      it 'has a link to choose a different 2FA method' do
        render

        expect(rendered).to have_link(
          t('two_factor_authentication.login_options_link_text'),
          href: login_two_factor_options_path,
        )
      end
    end

    context 'when choosing to receive OTP via voice' do
      let(:otp_delivery_preference) { 'voice' }

      before do
        controller.request.path_parameters[:otp_delivery_preference] = otp_delivery_preference
        voice_data = presenter_data.merge(otp_delivery_preference: otp_delivery_preference)
        @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(
          data: voice_data,
          view: view,
          service_provider: nil,
        )
      end

      it 'allows user to resend code using the same delivery method' do
        render

        resend_path = otp_send_path(
          otp_delivery_selection_form: {
            otp_delivery_preference: otp_delivery_preference,
            resend: true,
          },
        )

        expect(rendered).to have_link(
          t('links.two_factor_authentication.send_another_code'),
          href: resend_path,
        )
      end

      it 'has a fallback link to send confirmation as SMS' do
        render

        expect(rendered).to have_link(
          t('two_factor_authentication.login_options_link_text'),
          href: login_two_factor_options_path,
        )
      end
    end

    context 'when users phone number is unconfirmed' do
      it 'has a link to choose a new phone number' do
        data = presenter_data.merge(unconfirmed_phone: true)

        @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(
          data: data,
          view: view,
          service_provider: nil,
        )

        render

        expect(rendered).to have_link(t('forms.two_factor.try_again'), href: phone_setup_path)
      end
    end

    context 'when users phone number is unconfirmed' do
      it 'has a link to choose a new phone number' do
        data = presenter_data.merge(unconfirmed_phone: true)

        @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(
          data: data,
          view: view,
          service_provider: nil,
        )

        render
        expect(rendered).to have_link(t('forms.two_factor.try_again'), href: phone_setup_path)
      end
    end

    context 'with landline setup warning' do
      before do
        assign(:landline_alert, true)
      end

      it 'shows landline warning' do
        render

        expect(rendered).to have_link(
          'phone call',
          href: phone_setup_path(otp_delivery_preference: 'voice'),
        )
      end
    end

    describe 'countdown alert' do
      around do |example|
        freeze_time { example.run }
      end

      before do
        user = create(
          :user,
          :fully_registered,
          otp_delivery_preference: 'voice',
          direct_otp_sent_at: Time.zone.now,
        )
        allow(view).to receive(:current_user).and_return(user)
        otp_expiration = user.direct_otp_sent_at +
                         TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_SECONDS
        allow(@presenter).to receive(:otp_expiration).and_return(otp_expiration)
      end

      it 'should render countdown component' do
        render

        expect(rendered).to include('countdown-phase-alert')

        expect(rendered).to have_css(
          'lg-countdown[data-expiration].display-none[aria-hidden="true"]',
        )

        expect(rendered).to include(%(data-expiration="#{@presenter.otp_expiration.iso8601}"))
      end
    end

    context 'troubleshooting options content' do
      context 'when phone is unconfirmed' do
        it 'has option to change phone number' do
          data = presenter_data.merge(unconfirmed_phone: true)

          @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(
            data: data,
            view: view,
            service_provider: nil,
          )

          render

          expect(rendered).to have_link(
            t('two_factor_authentication.phone_verification.troubleshooting.change_number'),
            href: phone_setup_path,
          )
        end
      end

      context 'when phone is confirmed' do
        it 'has option to select different authentication method' do
          render

          expect(rendered).to have_link(
            t('two_factor_authentication.login_options_link_text'),
            href: login_two_factor_options_path,
          )
        end
      end
    end

    context 'legacy (non-nds) bucket' do
      it 'does not render the NDS form-page card' do
        render

        expect(rendered).not_to have_css('.auth--form-page')
      end
    end

    context 'nds bucket' do
      let(:enabled_mfa_methods_count) { 0 }
      let(:in_account_creation_flow) { true }
      let(:resend_path) do
        otp_send_path(
          otp_delivery_selection_form: {
            otp_delivery_preference: presenter_data[:otp_delivery_preference],
            resend: true,
          },
        )
      end

      before do
        allow(view).to receive(:nds_layout?).and_return(true)
        allow(view).to receive(:in_account_creation_flow?).and_return(in_account_creation_flow)
        allow(view).to receive(:enabled_mfa_methods_count).and_return(enabled_mfa_methods_count)
      end

      it 'renders the FormPageComponent card with the presenter heading' do
        render

        expect(rendered).to have_css('.auth--form-page')
        expect(rendered).to have_css('.auth--form-page h1', text: @presenter.header)
      end

      it 'renders the one-time code input inside the card' do
        render

        expect(rendered).to have_css('.auth--form-page lg-nds-input-otp .input-otp__input#code')
        expect(rendered).to have_css('.auth--form-page .input-otp__slots .input-otp__slot', count: 6)
      end

      it 'submits the code with a Continue primary button' do
        render

        expect(rendered).to have_button(t('forms.buttons.continue'))
      end

      it 'renders the resend control pointing at the resend path' do
        render

        expect(rendered).to have_link(
          t('links.two_factor_authentication.send_another_code'),
          href: resend_path,
        )
      end

      it 'renders the choose-another-method control' do
        render

        expect(rendered).to have_link(
          t('nds.mfa.choose_another_method'),
          href: login_two_factor_options_path,
        )
      end

      context 'in the multi-mfa selection flow' do
        before do
          data = presenter_data.merge(in_multi_mfa_selection_flow: true)
          @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(
            data: data,
            view: view,
            service_provider: nil,
          )
        end

        it 'points choose-another-method at the authentication methods setup page' do
          render

          expect(rendered).to have_link(
            t('nds.mfa.choose_another_method'),
            href: authentication_methods_setup_path,
          )
        end
      end

      context 'during account creation' do
        let(:in_account_creation_flow) { true }

        context 'confirming the first mfa method' do
          let(:enabled_mfa_methods_count) { 0 }

          it 'sets the Security header progress to substep 1 / 2' do
            render
            progress = view.content_for(:nds_header_progress)

            expect(progress).to have_css(
              '.progress__step[aria-current="step"]',
              text: t('step_indicator.flows.account_creation.security'),
            )
            expect(progress).to have_css(
              '.progress__step[aria-current="step"] .progress__step-counter',
              text: '1 / 2',
            )
          end
        end

        context 'confirming an additional mfa method' do
          let(:enabled_mfa_methods_count) { 1 }

          it 'sets the Security header progress to substep 2 / 2' do
            render
            progress = view.content_for(:nds_header_progress)

            expect(progress).to have_css(
              '.progress__step[aria-current="step"] .progress__step-counter',
              text: '2 / 2',
            )
          end
        end
      end

      context 'during sign-in (not account creation)' do
        let(:in_account_creation_flow) { false }

        it 'does not emit the account-creation header progress' do
          render

          expect(view.content_for(:nds_header_progress)).to be_nil
        end
      end

      context 'with a landline setup warning' do
        before { assign(:landline_alert, true) }

        it 'shows the landline warning inside the card' do
          render

          expect(rendered).to have_css('.auth--form-page .usa-alert--warning')
          expect(rendered).to have_css('.auth--form-page', text: /landline phone/)
        end
      end

      context 'with an OTP expiration' do
        around do |example|
          freeze_time { example.run }
        end

        before do
          otp_user = create(
            :user,
            :fully_registered,
            otp_delivery_preference: 'voice',
            direct_otp_sent_at: Time.zone.now,
          )
          allow(view).to receive(:current_user).and_return(otp_user)
          otp_expiration = otp_user.direct_otp_sent_at +
                           TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_SECONDS
          allow(@presenter).to receive(:otp_expiration).and_return(otp_expiration)
        end

        it 'renders the countdown alert with screen-reader live regions' do
          render

          expect(rendered).to include('countdown-phase-alert')
          expect(rendered).to have_css('#otp-live-phase[aria-live="polite"]', visible: :all)
          expect(rendered).to have_css('#otp-live-expiry[role="alert"]', visible: :all)
        end
      end
    end
  end
end
