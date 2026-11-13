require 'rails_helper'

RSpec.describe 'destructive_account_reset/pending/show.html.erb' do
  let(:waiting_period) { '24 hours' }
  let(:interval) { '23 hours and 42 minutes' }
  let(:pending_presenter) do
    instance_double(
      DestructiveAccountReset::PendingPresenter,
      account_reset_deletion_period: waiting_period,
      time_remaining_until_granted: interval,
    )
  end

  before do
    assign(:pending_presenter, pending_presenter)
    allow(view).to receive(:nds_layout?).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('destructive_account_reset.pending.header'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders the cancel request button' do
      expect(rendered).to have_button(t('destructive_account_reset.pending.cancel_request'))
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).not_to have_selector('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'renders the heading and the waiting period with the time remaining' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.auth__intro h1',
        text: t('destructive_account_reset.pending.header'),
      )
      expect(rendered).to have_css('.auth__intro-description', text: waiting_period)
      expect(rendered).to have_css('.auth__intro-description strong', text: interval)
    end

    it 'posts to the pending cancel path from the primary action' do
      expect(rendered).to have_css(
        ".auth__actions form[action='#{account_reset_pending_cancel_path}'] button.usa-button",
        text: t('nds.destructive_account_reset.pending.cancel_request'),
      )
    end

    it 'does not render the legacy cancel prompt' do
      expect(rendered).not_to have_content(
        strip_tags(t('destructive_account_reset.pending.cancel_request_prompt_html')),
      )
    end
  end
end
