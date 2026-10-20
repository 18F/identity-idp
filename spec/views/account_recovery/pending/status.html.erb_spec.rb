require 'rails_helper'

RSpec.describe 'account_recovery/pending/status.html.erb' do
  let(:state) { AccountRecoveryRequest::WAITING }
  let(:presenter) do
    instance_double(
      AccountRecovery::PendingPresenter,
      granted?: state == AccountRecoveryRequest::GRANTED,
      waiting_period: '24 hours',
      time_remaining_until_granted: '18 hours',
    )
  end

  before { assign(:pending_presenter, presenter) }

  %i[en es fr zh].each do |locale|
    it "shows the remaining wait and a cancel button in #{locale}" do
      I18n.with_locale(locale) do
        render

        expect(rendered).to have_css('h1', text: t('account_recovery.pending.status.header'))
        expect(rendered).to have_css('strong', text: '18 hours')
        expect(rendered).to have_content(t('account_recovery.pending.status.cancel_prompt'))
        expect(rendered).to have_css(
          "form[action=\"#{account_recovery_pending_cancel_path}\"][method=\"post\"]",
        )
        expect(rendered).to have_button(t('account_recovery.pending.status.cancel'))
      end
    end
  end

  context 'when the request has been granted' do
    let(:state) { AccountRecoveryRequest::GRANTED }

    it 'tells the user to check their email instead of showing a wait time' do
      render

      expect(rendered).to have_content(t('account_recovery.pending.status.granted'))
      expect(rendered).not_to have_css('strong', text: '18 hours')
      expect(rendered).to have_button(t('account_recovery.pending.status.cancel'))
    end
  end
end
