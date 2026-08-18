require 'rails_helper'

RSpec.describe 'idv/in_person/state_id/show.html.erb' do
  let(:pii) { {} }
  let(:form) { Idv::StateIdForm.new(pii) }
  let(:parsed_dob) { Date.new(1970, 1, 1) }
  let(:parsed_expiration) { Time.zone.today + 1.year }
  let(:presenter) { Idv::InPerson::UspsFormPresenter.new }
  let(:expiration_option) { nil }
  let(:expiration_edge_cases_enabled) { false }

  before do
    allow(view).to receive(:url_for).and_return('https://example.com/')
    assign(:presenter, presenter)
  end

  subject(:render_template) do
    render template: 'idv/in_person/state_id/show',
           locals: {
             updating_state_id: true,
             form: form,
             pii: pii,
             parsed_dob: parsed_dob,
             parsed_expiration: parsed_expiration,
             expiration_option: expiration_option,
             expiration_edge_cases_enabled: expiration_edge_cases_enabled,
           }
  end

  it 'renders state ID hint text with correct screenreader tags', aggregate_failures: true do
    render_template

    doc = Nokogiri::HTML(rendered)

    jurisdiction_extras = doc.at_css('.jurisdiction-extras')

    all_hints = jurisdiction_extras.css('[data-state]')
    shown = jurisdiction_extras.css('[data-state]:not(.display-none)')
    hidden = jurisdiction_extras.css('[data-state].display-none')

    expect(shown.size).to eq(1), 'only shows one hint'
    expect(shown.size + hidden.size).to eq(all_hints.size)

    default_hint = jurisdiction_extras.at_css('[data-state=default]')
    default_hint_screenreader_tags = default_hint.css('.usa-sr-only')
    *first, last = default_hint_screenreader_tags.map(&:text)
    expect(first).to all end_with(',')
    expect(last).to_not end_with(',')
  end

  context 'when the expiration edge cases feature is enabled (LG-17733)' do
    let(:expiration_edge_cases_enabled) { true }
    let(:expiration_option) { Idv::StateIdForm::EXPIRATION_OPTION_DATE }

    it 'renders the expiration date radio options' do
      render_template

      expect(rendered).to include(
        I18n.t('in_person_proofing.form.state_id.expiration_date_options.military'),
      )
      expect(rendered).to include(
        I18n.t('in_person_proofing.form.state_id.expiration_date_options.enter_date'),
      )
    end
  end

  context 'when the expiration edge cases feature is disabled' do
    let(:expiration_edge_cases_enabled) { false }

    it 'does not render the expiration date radio options' do
      render_template

      expect(rendered).to_not include(
        I18n.t('in_person_proofing.form.state_id.expiration_date_options.military'),
      )
    end
  end
end
