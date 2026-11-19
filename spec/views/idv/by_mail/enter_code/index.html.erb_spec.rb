require 'rails_helper'

RSpec.describe 'idv/by_mail/enter_code/index.html.erb' do
  let(:user) do
    create(:user)
  end
  let(:attempts_api_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:fraud_ops_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }

  let(:pii) do
    {}
  end

  let(:can_request_another_letter) { true }

  let(:user_did_not_receive_letter) { false }

  let(:last_date_letter_was_sent) { 2.days.ago }

  let(:nds_layout) { false }

  let(:otp_error) { nil }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:step_indicator_steps).and_return({})

    @gpo_verify_form = GpoVerifyForm.new(
      attempts_api_tracker:,
      fraud_ops_tracker:,
      user:,
      pii:,
      resolved_authn_context_result: Component::Parser::Result.no_sp_result,
      otp: '1234',
    )
    @gpo_verify_form.errors.add(:otp, otp_error) if otp_error

    @can_request_another_letter = can_request_another_letter
    @user_did_not_receive_letter = user_did_not_receive_letter
    @last_date_letter_was_sent = last_date_letter_was_sent

    render
  end

  it 'has a localized title' do
    expect(view.content_for(:title)).to eq(t('idv.gpo.title'))
  end

  context 'in the default layout' do
    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end

    context 'user is allowed to request another GPO letter' do
      it 'includes the send another letter link' do
        expect(rendered).to have_link(t('idv.messages.gpo.resend'), href: idv_resend_letter_path)
      end
    end

    context 'user is NOT allowed to request another GPO letter' do
      let(:can_request_another_letter) { false }
      it 'does not include the send another letter link' do
        expect(rendered).not_to have_link(
          t('idv.messages.gpo.resend'),
          href: idv_resend_letter_path,
        )
      end
    end

    context 'user clicked an "i didn\'t get my letter" link in an email' do
      let(:user_did_not_receive_letter) { true }

      it 'uses a special title' do
        expect(rendered).to have_css('h1', text: t('idv.gpo.did_not_receive_letter.title'))
      end

      it 'has a special body text' do
        expect(rendered).to have_content(
          strip_tags(
            t(
              'idv.gpo.did_not_receive_letter.intro_html',
              date_letter_was_sent: I18n.l(
                last_date_letter_was_sent,
                format: :event_date,
              ),
            ),
          ),
        )
        expect(rendered).to have_content(
          strip_tags(t('idv.gpo.did_not_receive_letter.request_a_new_letter_html')),
        )
      end

      it 'links to requesting a new letter' do
        expect(rendered).to have_link(
          t('idv.messages.gpo.resend'),
          href: idv_resend_letter_path,
        )
      end

      it 'has a special prompt to enter the otp' do
        expect(rendered).to have_content(
          t('idv.gpo.did_not_receive_letter.form.instructions'),
        )
      end

      context 'user is NOT allowed to request another GPO letter' do
        let(:can_request_another_letter) { false }

        it 'still has a special body text' do
          expect(rendered).to have_content(
            strip_tags(
              t(
                'idv.gpo.did_not_receive_letter.intro_html',
                date_letter_was_sent: I18n.l(
                  last_date_letter_was_sent,
                  format: :event_date,
                ),
              ),
            ),
          )
          expect(rendered).to have_content(
            strip_tags(t('idv.gpo.did_not_receive_letter.request_a_new_letter_html')),
          )
        end

        it 'does not link to requesting a new letter' do
          expect(rendered).to_not have_link(
            t('idv.messages.gpo.resend'),
            href: idv_resend_letter_path,
          )
        end
      end
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }
    let(:letter_date) { I18n.l(last_date_letter_was_sent, format: :event_date) }

    it 'renders the form-page card with the heading and intro' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: t('idv.gpo.title'))
      expect(rendered).to have_css('.auth__intro-description', text: t('idv.gpo.intro'))
    end

    it 'pins the progress to the enter password substep, after the letter was enqueued' do
      expect(view.content_for(:nds_header_progress)).to have_css(
        'nds-progress .progress__step[aria-current="step"] .progress__step-counter',
        text: '10 / 12',
      )
    end

    it 'posts the code to the enter code path behind the submit gate' do
      form_selector = "form[action='#{idv_verify_by_mail_enter_code_path}'][method='post']"
      expect(rendered).to have_css("#{form_selector}[data-nds-submit-gate]")
      expect(rendered).to have_field(
        t('idv.gpo.form.otp_label'),
        with: '1234',
        type: 'text',
      )
      expect(rendered).to have_css(
        "input[name='gpo_verify_form[otp]'][maxlength='10'][required][autofocus]",
      )
      expect(rendered).to have_css(
        "input[type='hidden'][name='did_not_receive_letter']:not([value])", visible: :all
      )
      expect(rendered).to have_css(
        '.auth__actions button[type=submit]',
        text: t('forms.buttons.continue'),
      )
    end

    it 'shows where the letter was sent after the actions, with the start over link' do
      expect(rendered).to have_css(
        '.auth__actions .usa-accordion .usa-accordion__button',
        text: t('idv.gpo.address_accordion.title'),
      )
      expect(rendered).to_not have_css('.auth__form-page-body .usa-accordion')
      expect(rendered).to have_content(t('idv.gpo.address_accordion.body'))
      expect(rendered).to have_link(
        t('idv.gpo.address_accordion.cta_link'),
        href: idv_confirm_start_over_path,
      )
    end

    it 'shows when the last letter was requested' do
      expect(rendered).to have_content(
        strip_tags(
          t('idv.gpo.last_letter_request_message_html', date_letter_was_sent: letter_date),
        ),
      )
    end

    it 'offers another letter and the profile link' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{idv_resend_letter_path}']",
        text: t('idv.messages.gpo.resend'),
      )
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{account_path}']",
        text: t('idv.gpo.return_to_profile'),
      )
    end

    it 'does not show the letter limit warning' do
      expect(rendered).to_not have_content(
        strip_tags(t('idv.gpo.alert_rate_limit_warning_html', date_letter_was_sent: letter_date)),
      )
    end

    context 'with an incorrect code' do
      let(:otp_error) { :confirmation_code_incorrect }

      it 'shows the error on the field' do
        expect(rendered).to have_css(
          '.usa-input__error--visible',
          text: t('errors.messages.confirmation_code_incorrect'),
        )
        expect(rendered).to have_css("input[name='gpo_verify_form[otp]'][aria-invalid='true']")
      end
    end

    context 'user is NOT allowed to request another GPO letter' do
      let(:can_request_another_letter) { false }

      it 'shows the letter limit warning and hides the another letter action' do
        expect(rendered).to have_css(
          '.usa-alert--warning',
          text: strip_tags(
            t('idv.gpo.alert_rate_limit_warning_html', date_letter_was_sent: letter_date),
          ),
        )
        expect(rendered).to_not have_link(t('idv.messages.gpo.resend'))
      end
    end

    context 'user clicked an "i didn\'t get my letter" link in an email' do
      let(:user_did_not_receive_letter) { true }

      it 'uses the special title' do
        expect(view.content_for(:title)).to eq(t('idv.gpo.did_not_receive_letter.title'))
        expect(rendered).to have_css(
          '.auth--form-page h1',
          text: t('idv.gpo.did_not_receive_letter.title'),
        )
      end

      it 'explains when to request a new letter and how to enter the code' do
        expect(rendered).to have_css(
          '.auth__intro-description',
          text: strip_tags(
            t('idv.gpo.did_not_receive_letter.intro_html', date_letter_was_sent: letter_date),
          ),
        )
        expect(rendered).to have_css(
          '.auth__intro-description',
          text: strip_tags(t('idv.gpo.did_not_receive_letter.request_a_new_letter_html')),
        )
        expect(rendered).to have_content(t('idv.gpo.did_not_receive_letter.form.instructions'))
        expect(rendered).to_not have_content(
          strip_tags(
            t('idv.gpo.last_letter_request_message_html', date_letter_was_sent: letter_date),
          ),
        )
      end

      it 'keeps the did not receive letter flag in the form' do
        expect(rendered).to have_css(
          "input[type='hidden'][name='did_not_receive_letter'][value='1']", visible: :all
        )
      end

      it 'offers another letter right after the intro, before the code field' do
        expect(rendered).to have_css(
          ".auth__form-page-body a.usa-button[href='#{idv_resend_letter_path}']",
          text: t('idv.messages.gpo.resend'),
        )
        expect(rendered).to_not have_css(".auth__actions a[href='#{idv_resend_letter_path}']")
        body = Nokogiri::HTML(rendered).at_css('.auth__form-page-body').to_html
        expect(body.index(idv_resend_letter_path)).to be < body.index('gpo_verify_form[otp]')
      end

      context 'user is NOT allowed to request another GPO letter' do
        let(:can_request_another_letter) { false }

        it 'does not offer another letter' do
          expect(rendered).to_not have_link(t('idv.messages.gpo.resend'))
        end
      end
    end
  end
end
