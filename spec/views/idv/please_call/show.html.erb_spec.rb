require 'rails_helper'

RSpec.describe 'idv/please_call/show.html.erb' do
  let(:in_person_proofing_enabled) { false }
  let(:in_person) { false }
  before do
    @call_by_date = Date.new(2023, 10, 13)
    @in_person = in_person
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled)
      .and_return(in_person_proofing_enabled)
    render
  end

  it 'shows step indicator with pending status on secure account' do
    progress = view.instance_variable_get(:@ads_progress_component)
    expect(progress).to be_a(ProgressComponent)
    expect(progress.steps[progress.current_step]).to eq(t('step_indicator.flows.idv.re_enter_password'))
  end

  it 'includes a message instructing them to fill out a contact form' do
    expect(rendered).to have_text(
      strip_tags(
        t(
          'idv.failure.setup.fail_html',
          support_code: 'ABCD',
          contact_number: '(844) 555-5555',
        ),
      ),
    )
  end

  context 'ipp enabled' do
    let(:in_person_proofing_enabled) { true }
    let(:in_person) { true }

    it 'does not show step indicator secure account' do
      expect(view.instance_variable_get(:@ads_progress_component)).to be_nil
    end
  end
end
