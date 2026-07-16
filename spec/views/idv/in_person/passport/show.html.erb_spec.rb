require 'rails_helper'

RSpec.describe 'idv/in_person/passport/show.html.erb' do
  before do
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
  end

  context 'show' do
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
        expect(rendered).to have_field('in_person_passport[passport_surname]')
        expect(rendered).to have_field('in_person_passport[passport_first_name]')
        expect(rendered).to have_field('passport_dob_date')
        expect(rendered).to have_field('in_person_passport[passport_number]', type: :password)
        expect(rendered).to have_button(t('forms.passport.show'))
        expect(rendered).to have_field('passport_expiration_date')
      end

      it 'renders submit and choose another ID type' do
        expect(rendered).to have_button(t('forms.buttons.submit.default'))
        expect(rendered).to have_link(
          t('in_person_proofing.form.passport.choose_another_id_type'),
          href: idv_in_person_choose_id_type_url,
        )
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

      it 'renders passport fields with values' do
        expect(rendered).to have_field(
          'in_person_passport[passport_surname]',
          with: pii[:passport_surname],
        )
        expect(rendered).to have_field(
          'in_person_passport[passport_first_name]',
          with: pii[:passport_first_name],
        )
        expect(rendered).to have_field('passport_dob_date', with: '1985-10-13')
        expect(rendered).to have_field(
          'in_person_passport[passport_dob][year]',
          with: dob_year,
          type: :hidden,
        )
        expect(rendered).to have_field(
          'in_person_passport[passport_dob][month]',
          with: format('%02d', dob_month),
          type: :hidden,
        )
        expect(rendered).to have_field(
          'in_person_passport[passport_dob][day]',
          with: format('%02d', dob_day),
          type: :hidden,
        )
        expect(rendered).to have_field(
          'in_person_passport[passport_number]',
          with: pii[:passport_number],
          type: :password,
        )
        expect(rendered).to have_button(t('forms.passport.show'))
        expect(rendered).to have_field('passport_expiration_date', with: '2100-12-20')
        expect(rendered).to have_field(
          'in_person_passport[passport_expiration][year]',
          with: expiration_year,
          type: :hidden,
        )
        expect(rendered).to have_field(
          'in_person_passport[passport_expiration][month]',
          with: format('%02d', expiration_month),
          type: :hidden,
        )
        expect(rendered).to have_field(
          'in_person_passport[passport_expiration][day]',
          with: format('%02d', expiration_day),
          type: :hidden,
        )
      end

      it 'renders submit and choose another ID type' do
        expect(rendered).to have_button(t('forms.buttons.submit.default'))
        expect(rendered).to have_link(
          t('in_person_proofing.form.passport.choose_another_id_type'),
          href: idv_in_person_choose_id_type_url,
        )
      end
    end
  end
end
