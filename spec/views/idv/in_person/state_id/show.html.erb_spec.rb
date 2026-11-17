require 'rails_helper'

RSpec.describe 'idv/in_person/state_id/show.html.erb' do
  let(:pii) { {} }
  let(:form) { Idv::StateIdForm.new(pii) }
  let(:parsed_dob) { Date.new(1970, 1, 1) }
  let(:parsed_expiration) { Time.zone.today + 1.year }
  let(:presenter) { Idv::InPerson::UspsFormPresenter.new }
  let(:expiration_option) { nil }
  let(:expiration_edge_cases_enabled) { false }
  let(:updating_state_id) { true }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:url_for).and_return('https://example.com/')
    assign(:presenter, presenter)
  end

  subject(:render_template) do
    render template: 'idv/in_person/state_id/show',
           locals: {
             updating_state_id:,
             form: form,
             pii: pii,
             parsed_dob: parsed_dob,
             parsed_expiration: parsed_expiration,
             expiration_option: expiration_option,
             expiration_edge_cases_enabled: expiration_edge_cases_enabled,
           }
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('in_person_proofing.headings.update_state_id'))

    render_template
  end

  context 'in the default layout' do
    it 'does not render the NDS form-page card' do
      render_template

      expect(rendered).to_not have_selector('.auth--form-page')
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

  context 'in the NDS layout' do
    let(:updating_state_id) { false }

    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      allow(view).to receive(:user_signing_up?).and_return(false)
    end

    it 'renders the form-page card with the state ID heading and intro' do
      render_template

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css(
        'h1',
        text: t('in_person_proofing.headings.state_id_milestone_2'),
      )
      expect(rendered).to have_content(strip_tags(t('in_person_proofing.body.state_id.info_html')))
      expect(rendered).to have_content(t('in_person_proofing.body.state_id.alert_message'))
    end

    it 'pins the verification stepper' do
      render_template

      progress = Capybara.string(view.content_for(:nds_header_progress))
      expect(progress).to have_css('.progress__step-counter', text: '4 / 12')
    end

    it 'puts the same fields to the same path under the identity_doc param' do
      render_template

      expect(rendered).to have_css(
        'form[action="https://example.com/"]:not([data-nds-submit-gate]) ' \
        'input[name="_method"][value="put"]',
        visible: :all,
      )
      %w[
        first_name last_name id_number identity_doc_address1 identity_doc_address2
        identity_doc_city identity_doc_zipcode
      ].each do |field|
        expect(rendered).to have_field("identity_doc[#{field}]")
      end
      expect(rendered).to have_select('identity_doc[state_id_jurisdiction]')
      expect(rendered).to have_select('identity_doc[identity_doc_address_state]')
      %w[month day year].each do |part|
        expect(rendered).to have_field("identity_doc[dob][#{part}]")
        expect(rendered).to have_field("identity_doc[id_expiration][#{part}]")
      end
      expect(rendered).to have_field(
        t('in_person_proofing.form.state_id.id_type_drivers_license'),
        type: :radio,
      )
      expect(rendered).to have_field(
        t('in_person_proofing.form.state_id.current_address_matches_id_yes'),
        type: :radio,
      )
      expect(rendered).to have_css('.jurisdiction-state-selector')
      expect(rendered).to have_css('.address-state-selector')
      expect(rendered).to have_css('.jurisdiction-extras [data-state=default]')
    end

    it 'renders Continue and a cancel link' do
      render_template

      expect(rendered).to have_button(t('forms.buttons.continue'))
      expect(rendered).to have_link(
        t('links.cancel'),
        href: idv_cancel_path(step: 'state_id'),
      )
    end

    context 'when updating the state ID' do
      let(:updating_state_id) { true }

      it 'renders the update heading, Update and Back' do
        render_template

        expect(rendered).to have_css('h1', text: t('in_person_proofing.headings.update_state_id'))
        expect(rendered).to have_button(t('forms.buttons.submit.update'))
        expect(rendered).to have_link(
          t('forms.buttons.back'),
          href: idv_in_person_verify_info_path,
        )
      end
    end

    context 'with saved PII' do
      let(:pii) do
        Idp::Constants::MOCK_IPP_APPLICANT.merge(
          state_id_jurisdiction: 'VA',
          asserted_id_type: Idp::Constants::DocumentTypes::STATE_ID_CARD,
          ipp_current_address_matches_id: false,
        )
      end

      it 'prefills the fields' do
        render_template

        expect(rendered).to have_field('identity_doc[first_name]', with: 'FAKEY')
        expect(rendered).to have_field('identity_doc[id_number]', with: '1111111111111')
        expect(rendered).to have_select('identity_doc[state_id_jurisdiction]', selected: 'Virginia')
        expect(rendered).to have_checked_field(
          t('in_person_proofing.form.state_id.id_type_state_id'),
        )
        expect(rendered).to have_checked_field(
          t('in_person_proofing.form.state_id.current_address_matches_id_no'),
        )
      end
    end

    context 'when the expiration edge cases feature is enabled' do
      let(:expiration_edge_cases_enabled) { true }
      let(:expiration_option) { Idv::StateIdForm::EXPIRATION_MILITARY }

      it 'renders the expiration options with the date inputs hidden' do
        render_template

        expect(rendered).to have_checked_field(
          t('in_person_proofing.form.state_id.expiration_date_options.military'),
        )
        expect(rendered).to have_css('.expiration-date-inputs.display-none', visible: :all)
      end
    end

    context 'with a server-side field error' do
      before do
        form.errors.add(:first_name, 'Unsupported characters')
      end

      it 'shows the error on the field' do
        render_template

        expect(rendered).to have_css('.usa-input__error--visible', text: 'Unsupported characters')
      end
    end

    it 'labels both state selects visibly with a select prompt' do
      render_template

      expect(rendered).to have_css(
        'label.usa-label[for="identity_doc_state_id_jurisdiction"]',
        text: t('in_person_proofing.form.state_id.state_id_jurisdiction'),
      )
      expect(rendered).to have_css(
        'label.usa-label[for="identity_doc_identity_doc_address_state"]',
        text: t('in_person_proofing.form.state_id.identity_doc_address_state'),
      )
      expect(rendered).to have_css(
        '#identity_doc_state_id_jurisdiction option[value=""]',
        text: t('in_person_proofing.form.state_id.state_id_jurisdiction_prompt'),
      )
    end

    context 'with server-side errors on selects and radios' do
      before do
        form.errors.add(:state_id_jurisdiction, 'Pick a state')
        form.errors.add(:asserted_id_type, 'Pick an ID type')
      end

      it 'ties each error to its control' do
        render_template

        expect(rendered).to have_css(
          'select#identity_doc_state_id_jurisdiction[aria-invalid="true"]' \
          '[aria-describedby="identity_doc_state_id_jurisdiction_hint ' \
          'identity_doc_state_id_jurisdiction_error"]',
        )
        expect(rendered).to have_css(
          '#identity_doc_state_id_jurisdiction_error.usa-error-message',
          text: 'Pick a state',
        )
        expect(rendered).to have_css(
          'input[name="identity_doc[asserted_id_type]"][aria-invalid="true"]' \
          '[aria-describedby="identity_doc_asserted_id_type_error"]',
          count: 2,
        )
        expect(rendered).to have_css(
          '#identity_doc_asserted_id_type_error',
          text: 'Pick an ID type',
        )
      end
    end
  end
end
