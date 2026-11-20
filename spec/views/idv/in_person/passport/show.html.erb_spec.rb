require 'rails_helper'

RSpec.describe 'idv/in_person/passport/show.html.erb' do
  let(:pii) { {} }
  let(:form) { Idv::InPerson::PassportForm.new }
  let(:parsed_dob) { nil }
  let(:parsed_expiration) { nil }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('in_person_proofing.headings.passport'))

    render template: 'idv/in_person/passport/show',
           locals: { form:, pii:, parsed_dob:, parsed_expiration: }
  end

  context 'in the default layout' do
    it 'does not render the NDS form-page card' do
      render template: 'idv/in_person/passport/show',
             locals: { form:, pii:, parsed_dob:, parsed_expiration: }

      expect(rendered).to_not have_selector('.auth--form-page')
    end

    context 'When the user has not existing PII' do
      let(:pii) { {} }
      let(:form) { Idv::InPerson::PassportForm.new }
      let(:parsed_dob) { nil }
      let(:parsed_expiration) { nil }

      subject(:rendered) do
        render template: 'idv/in_person/passport/show',
               locals: { form:, pii:, parsed_dob:, parsed_expiration: }
      end

      it 'renders title with passport info' do
        expect(rendered).to have_content(t('in_person_proofing.headings.passport'))
        expect(rendered).to have_content(t('in_person_proofing.body.passport.info'))
      end

      it 'renders passport fields' do
        # Surname
        expect(rendered).to have_content(t('in_person_proofing.form.passport.surname'))
        # First name
        expect(rendered).to have_content(t('in_person_proofing.form.passport.first_name_hint'))
        expect(rendered).to have_content(t('in_person_proofing.form.passport.first_name'))
        # Date of birth
        expect(rendered).to have_content(t('in_person_proofing.form.passport.dob_hint'))
        expect(rendered).to have_content(t('in_person_proofing.form.passport.dob'))
        # Passport
        expect(rendered).to have_content(t('in_person_proofing.form.passport.passport_number_hint'))
        expect(rendered).to have_content(t('in_person_proofing.form.passport.passport_number'))
        # Expiration date
        expect(rendered).to have_content(t('in_person_proofing.form.passport.expiration_date_hint'))
        expect(rendered).to have_content(t('in_person_proofing.form.passport.expiration_date'))
      end

      it 'renders submit' do
        expect(rendered).to have_content(t('forms.buttons.submit.default'))
      end

      it 'renders troubleshooting content' do
        expect(rendered).to have_content(t('components.troubleshooting_options.default_heading'))
        expect(rendered).to have_content(t('idv.troubleshooting.options.use_another_id_type'))
      end

      it 'renders a cancel link' do
        expect(rendered).to have_link(t('links.cancel'))
      end
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
          passport_surname: Faker::Name.last_name,
          passport_first_name: Faker::Name.first_name,
          passport_dob: '1985-10-13',
          passport_number: '123456789',
          passport_expiration: '2100-12-20',
        }
      end
      let(:form) { Idv::InPerson::PassportForm.new }
      let(:parsed_dob) { Date.new(dob_year, dob_month, dob_day) }
      let(:parsed_expiration) { Date.new(expiration_year, expiration_month, expiration_day) }

      subject(:rendered) do
        render template: 'idv/in_person/passport/show',
               locals: { form:, pii:, parsed_dob:, parsed_expiration: }
      end

      it 'renders title with passport info' do
        expect(rendered).to have_content(t('in_person_proofing.headings.passport'))
        expect(rendered).to have_content(t('in_person_proofing.body.passport.info'))
      end

      it 'renders passport fields' do
        # Surname
        expect(rendered).to have_field(
          'in_person_passport[passport_surname]',
          with: pii[:passport_surname],
        )
        # First name
        expect(rendered).to have_content(t('in_person_proofing.form.passport.first_name_hint'))
        expect(rendered).to have_field(
          'in_person_passport[passport_first_name]',
          with: pii[:passport_first_name],
        )
        # Date of birth
        expect(rendered).to have_content(t('in_person_proofing.form.passport.dob_hint'))
        expect(rendered).to have_field(
          'in_person_passport[passport_dob][day]',
          with: dob_day,
        )
        expect(rendered).to have_field(
          'in_person_passport[passport_dob][month]',
          with: dob_month,
        )
        expect(rendered).to have_field(
          'in_person_passport[passport_dob][year]',
          with: dob_year,
        )
        # Passport
        expect(rendered).to have_content(t('in_person_proofing.form.passport.passport_number_hint'))
        expect(rendered).to have_field(
          'in_person_passport[passport_number]',
          with: pii[:passport_number],
        )
        # Expiration date
        expect(rendered).to have_content(t('in_person_proofing.form.passport.expiration_date_hint'))
        expect(rendered).to have_field(
          'in_person_passport[passport_expiration][day]',
          with: expiration_day,
        )
        expect(rendered).to have_field(
          'in_person_passport[passport_expiration][month]',
          with: expiration_month,
        )
        expect(rendered).to have_field(
          'in_person_passport[passport_expiration][year]',
          with: expiration_year,
        )
      end

      it 'renders submit' do
        expect(rendered).to have_content(t('forms.buttons.submit.default'))
      end

      it 'renders troubleshooting content' do
        expect(rendered).to have_content(t('components.troubleshooting_options.default_heading'))
        expect(rendered).to have_content(t('idv.troubleshooting.options.use_another_id_type'))
      end

      it 'renders a cancel link' do
        expect(rendered).to have_link(t('links.cancel'))
      end
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    subject(:rendered) do
      render template: 'idv/in_person/passport/show',
             locals: { form:, pii:, parsed_dob:, parsed_expiration: }
    end

    it 'renders the form-page card with the passport heading and intro' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('h1', text: t('in_person_proofing.headings.passport'))
      expect(rendered).to have_content(t('in_person_proofing.body.passport.info'))
    end

    it 'pins the verification stepper' do
      rendered

      progress = Capybara.string(view.content_for(:nds_header_progress))
      expect(progress).to have_css('.progress__step-counter', text: '4 / 12')
    end

    it 'puts the same passport fields to the passport path' do
      expect(rendered).to have_css(
        "form[action='#{idv_in_person_passport_url}']:not([data-nds-submit-gate])",
      )
      expect(rendered).to have_css('input[name="_method"][value="put"]', visible: :all)
      expect(rendered).to have_field('in_person_passport[passport_surname]')
      expect(rendered).to have_field('in_person_passport[passport_first_name]')
      expect(rendered).to have_css(
        'input[name="in_person_passport[passport_number]"]' \
        '[maxlength="9"][pattern="[0-9A-Za-z]{9}"]',
      )
      %w[month day year].each do |part|
        expect(rendered).to have_field("in_person_passport[passport_dob][#{part}]")
        expect(rendered).to have_field("in_person_passport[passport_expiration][#{part}]")
      end
      expect(rendered).to have_content(t('in_person_proofing.form.passport.first_name_hint'))
      expect(rendered).to have_content(t('in_person_proofing.form.passport.passport_number_hint'))
    end

    it 'renders Submit, the cancel link and the other ID type option' do
      expect(rendered).to have_css(
        '.auth__actions button[type=submit]',
        text: t('forms.buttons.submit.default'),
      )
      expect(rendered).to have_link(t('links.cancel'), href: idv_cancel_path(step: 'passport'))
      expect(rendered).to have_content(t('components.troubleshooting_options.default_heading'))
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.use_another_id_type'),
        href: idv_in_person_choose_id_type_url,
      )
    end

    context 'with saved PII' do
      let(:pii) do
        {
          passport_surname: 'Smith',
          passport_first_name: 'Jane',
          passport_number: '123456789',
        }
      end
      let(:parsed_dob) { Date.new(1985, 10, 13) }

      it 'prefills the fields' do
        expect(rendered).to have_field('in_person_passport[passport_surname]', with: 'Smith')
        expect(rendered).to have_field('in_person_passport[passport_number]', with: '123456789')
        expect(rendered).to have_field('in_person_passport[passport_dob][year]', with: '1985')
      end
    end
  end
end
