require 'rails_helper'

RSpec.describe 'idv/in_person/state_id/show.html.erb' do
  let(:pii) { {} }
  let(:form) { Idv::StateIdForm.new(pii) }
  let(:parsed_dob) { nil }
  let(:parsed_expiration) { nil }
  let(:presenter) { Idv::InPerson::UspsFormPresenter.new }

  before do
    allow(view).to receive(:url_for).and_return('https://example.com/')
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
    assign(:presenter, presenter)
  end

  subject(:rendered) do
    render template: 'idv/in_person/state_id/show',
           locals: {
             updating_state_id: false,
             form: form,
             pii: pii,
             parsed_dob: parsed_dob,
             parsed_expiration: parsed_expiration,
           }
  end

  it 'renders title, subtitle, and alert below intro' do
    expect(rendered).to have_css('h1', text: /state.issued/i)
    expect(rendered).to have_content(t('in_person_proofing.body.state_id.info_ads'))
    expect(rendered).to have_css(
      '.ads-auth__header + .ads-alert',
      text: t('in_person_proofing.body.state_id.alert_message'),
    )
  end

  it 'renders floating fields, native dates, and secure ID number' do
    expect(rendered).to have_field('identity_doc[first_name]')
    expect(rendered).to have_field('identity_doc[last_name]')
    expect(rendered).to have_field('dob_date')
    expect(rendered).to have_field('identity_doc[state_id_jurisdiction]')
    expect(rendered).to have_field('identity_doc[id_number]', type: :password)
    expect(rendered).to have_button(t('forms.state_id.show'))
    expect(rendered).to have_field('id_expiration_date')
  end

  it 'renders address section and same-address radios without a visible heading' do
    expect(rendered).to have_css('h2', text: t('in_person_proofing.headings.id_address'))
    expect(rendered).not_to have_css(
      'fieldset legend:not(.ads-sr-only)',
      text: t('in_person_proofing.form.state_id.same_address_as_id'),
    )
    expect(rendered).to have_field(
      t('in_person_proofing.form.state_id.same_address_as_id_yes'),
      type: :radio,
    )
    expect(rendered).to have_field(
      t('in_person_proofing.form.state_id.same_address_as_id_no'),
      type: :radio,
    )
  end

  it 'renders continue' do
    expect(rendered).to have_button(t('forms.buttons.continue'))
  end

  context 'when the user has existing PII' do
    let(:dob_day) { 13 }
    let(:dob_month) { 10 }
    let(:dob_year) { 1985 }
    let(:expiration_day) { 20 }
    let(:expiration_month) { 12 }
    let(:expiration_year) { 2100 }
    let(:pii) do
      {
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        dob: '1985-10-13',
        state_id_jurisdiction: 'NY',
        state_id_number: 'S59397998',
        id_expiration: '2100-12-20',
      }
    end
    let(:parsed_dob) { Date.new(dob_year, dob_month, dob_day) }
    let(:parsed_expiration) { Date.new(expiration_year, expiration_month, expiration_day) }

    it 'renders date fields with values and hidden bridges' do
      expect(rendered).to have_field('dob_date', with: '1985-10-13')
      expect(rendered).to have_field(
        'identity_doc[dob][year]',
        with: dob_year,
        type: :hidden,
      )
      expect(rendered).to have_field(
        'identity_doc[dob][month]',
        with: format('%02d', dob_month),
        type: :hidden,
      )
      expect(rendered).to have_field(
        'identity_doc[dob][day]',
        with: format('%02d', dob_day),
        type: :hidden,
      )
      expect(rendered).to have_field('id_expiration_date', with: '2100-12-20')
      expect(rendered).to have_field(
        'identity_doc[id_number]',
        with: pii[:state_id_number],
        type: :password,
      )
    end
  end
end
