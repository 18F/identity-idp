require 'rails_helper'

RSpec.describe 'account_recovery/pending/status.html.erb' do
  %i[en es fr zh].each do |locale|
    it "shows remaining time and a POST cancellation form in #{locale}" do
      I18n.with_locale(locale) do
        assign(:remaining_interval, '12 hours')

        render

        expect(rendered).to have_content(
          t('account_recovery.pending.time_remaining', interval: '12 hours'),
        )
        expect(rendered).to have_content(t('account_recovery.pending.cancel_instructions'))
        expect(rendered).to have_css(
          "form[action=\"#{account_recovery_cancel_path}\"][method=\"post\"]",
        )
        expect(rendered).to have_button(t('account_recovery.pending.cancel'))
      end
    end
  end

  it 'does not promise recovery is complete when the waiting period ends' do
    assign(:remaining_interval, nil)

    render

    expect(rendered).to have_content(t('account_recovery.pending.wait_ended'))
    expect(rendered).to have_button(t('account_recovery.pending.cancel'))
  end
end
