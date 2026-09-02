require 'rails_helper'

RSpec.describe NDS::AccountCreationProgressHelper, type: :helper do
  before do
    allow_any_instance_of(BaseComponent).to receive(:nds_bucket?).and_return(true)
  end

  it 'renders the progress stepper for the account step with a substep counter' do
    rendered = Capybara.string(helper.nds_account_creation_progress(step: :account, substep: 1))
    expect(rendered).to have_css('nds-progress.progress')
    expect(rendered).to have_css('.progress__step', count: 3)
    expect(rendered).to have_css(
      '.progress__step[aria-current="step"] .progress__step-counter',
      text: '1 / 2',
    )
  end

  it 'renders the security step without a substep counter' do
    rendered = Capybara.string(helper.nds_account_creation_progress(step: :security))
    active = rendered.find('.progress__step[aria-current="step"]')
    expect(active).to have_text(I18n.t('step_indicator.flows.account_creation.security'))
    expect(rendered).not_to have_css('.progress__step-counter')
  end
end
