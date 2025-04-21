require 'rails_helper'

RSpec.describe 'idv/in_person/passport/show.html.erb' do
  let(:pii) { {} }
  let(:updating_state_id) { false }
  let(:parsed_dob) { Date.new(1970, 1, 1) }

  before do
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
    @idv_in_person_passport_form = Idv::InPerson::PassportForm.new
  end

  subject(:rendered) { render template: 'idv/in_person/passport/show' }

  context 'show' do
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

    it 'renders continue' do
      expect(rendered).to have_content(t('forms.buttons.continue'))
    end

    it 'renders troubleshooting content' do
      expect(rendered).to have_content(t('components.troubleshooting_options.default_heading'))
      expect(rendered).to have_content(t('in_person_proofing.form.passport.redirect_to_state_id'))
    end

    it 'renders a cancel link' do
      expect(rendered).to have_link(t('links.cancel'))
    end
  end
end
