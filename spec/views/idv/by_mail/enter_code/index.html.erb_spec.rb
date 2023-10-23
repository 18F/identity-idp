require 'rails_helper'

RSpec.describe 'idv/by_mail/enter_code/index.html.erb' do
  let(:user) do
    create(:user)
  end

  let(:pii) do
    {}
  end

  let(:can_request_another_letter) { true }

  let(:user_did_not_receive_letter) { false }

  let(:last_date_letter_was_sent) { 2.days.ago }

  before do
    allow(view).to receive(:step_indicator_steps).and_return({})

    @gpo_verify_form = GpoVerifyForm.new(
      user: user,
      pii: pii,
      otp: '1234',
    )

    @can_request_another_letter = can_request_another_letter
    @user_did_not_receive_letter = user_did_not_receive_letter
    @last_date_letter_was_sent = last_date_letter_was_sent

    render
  end

  context 'user is allowed to request another GPO letter' do
    it 'includes the send another letter link' do
      expect(rendered).to have_link(t('idv.messages.gpo.resend'), href: idv_request_letter_path)
    end
  end

  context 'user is NOT allowed to request another GPO letter' do
    let(:can_request_another_letter) { false }
    it 'does not include the send another letter link' do
      expect(rendered).not_to have_link(t('idv.messages.gpo.resend'), href: idv_request_letter_path)
    end
  end

  context 'user clicked an "i didn\'t get my letter" link in an email' do
    let(:user_did_not_receive_letter) { true }

    it 'uses a special title' do
      expect(rendered).to have_css('h1', text: t('idv.gpo.did_not_receive_letter.title'))
    end

    it 'has a special intro paragraph' do
      expect(rendered).to have_content(
        strip_tags(
          t(
            'idv.gpo.did_not_receive_letter.intro.request_new_letter_prompt_html',
            request_new_letter_link:
              t('idv.gpo.did_not_receive_letter.intro.request_new_letter_link'),
          ),
        ),
      )
      expect(rendered).to have_content(
        strip_tags(t('idv.gpo.did_not_receive_letter.intro.be_patient_html')),
      )
    end

    it 'links to requesting a new letter' do
      expect(rendered).to have_link(
        t('idv.gpo.did_not_receive_letter.intro.request_new_letter_link'),
        href: idv_request_letter_path,
      )
    end

    it 'has a special prompt to enter the otp' do
      expect(rendered).to have_content(
        t('idv.gpo.did_not_receive_letter.form.instructions'),
      )
    end

    it 'does not link to requesting a new letter at the bottom of the page' do
      expect(rendered).not_to have_link(
        t('idv.messages.gpo.resend'),
        href: idv_request_letter_path,
      )
    end

    context 'user is NOT allowed to request another GPO letter' do
      let(:can_request_another_letter) { false }

      it 'still has a special intro' do
        expect(rendered).to have_content(
          strip_tags(t('idv.gpo.did_not_receive_letter.intro.be_patient_html')),
        )
      end

      it 'does not link to requesting a new letter' do
        expect(rendered).not_to have_link(
          t('idv.gpo.did_not_receive_letter.intro.request_new_letter_link'),
          href: idv_request_letter_path,
        )
      end
    end
  end
end
