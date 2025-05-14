require 'rails_helper'

RSpec.describe 'idv/in_person/verify_info/show.html.erb' do
  let(:address_pii) do
    {
      address1: Faker::Address.street_address,
      address2: Faker::Address.secondary_address,
      city: Faker::Address.city,
      state: Faker::Address.state_abbr,
      zipcode: Faker::Address.zip,
    }
  end

  let(:ssn_pii) do
    {
      ssn: '666' + Faker::Number.number(digits: 6).to_s,
    }
  end

  before do
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
  end

  describe 'show' do
    context 'When the user is in the state_id flow' do
      let(:state_id_pii) do
        {
          first_name: Faker::Name.first_name,
          last_name: Faker::Name.last_name,
          dob: Faker::Date.in_date_period(year: 1985).to_s,
          state_id_jurisdiction: Faker::Address.state_abbr,
          state_id_number: Faker::Number.number(digits: 6).to_s,
          identity_doc_address1: Faker::Address.street_address,
          identity_doc_address2: Faker::Address.secondary_address,
          identity_doc_city: Faker::Address.city,
          identity_doc_address_state: Faker::Address.state_abbr,
          identity_doc_zipcode: Faker::Address.zip,
        }
      end

      let(:pii) { { **state_id_pii, **address_pii, **ssn_pii } }
      let(:enrollment) { build(:in_person_enrollment, :state_id) }

      subject(:rendered) do
        render template: 'idv/in_person/verify_info/show'
      end

      before do
        assign(:presenter, Idv::InPerson::VerifyInfoPresenter.new(enrollment: enrollment))
        assign(:pii, pii)
        assign(:ssn, pii[:ssn])
      end

      it 'renders the state_id section' do
        # Heading
        expect(rendered).to have_content(t('headings.state_id'))
        # First Name
        expect(rendered).to have_content(t('idv.form.first_name'))
        expect(rendered).to have_content(pii[:first_name])
        # Last Name
        expect(rendered).to have_content(t('idv.form.last_name'))
        expect(rendered).to have_content(pii[:last_name])
        # Date of Birth
        expect(rendered).to have_content(t('idv.form.dob'))
        expect(rendered).to have_content(
          I18n.l(Date.parse(pii[:dob]), format: I18n.t('time.formats.event_date')),
        )
        # Issuing State
        expect(rendered).to have_content(t('idv.form.issuing_state'))
        expect(rendered).to have_content(pii[:state_id_jurisdiction])
        # State ID number
        expect(rendered).to have_content(t('idv.form.id_number'))
        expect(rendered).to have_content(pii[:state_id_number])
        # State ID address 1
        expect(rendered).to have_content(t('idv.form.address1'))
        expect(rendered).to have_content(pii[:identity_doc_address1])
        # State ID address 2
        expect(rendered).to have_content(t('idv.form.address2'))
        expect(rendered).to have_content(pii[:identity_doc_address2])
        # State ID address city
        expect(rendered).to have_content(t('idv.form.city'))
        expect(rendered).to have_content(pii[:identity_doc_city])
        # State ID address state
        expect(rendered).to have_content(t('idv.form.state'))
        expect(rendered).to have_content(pii[:identity_doc_address_state])
        # State ID address zipcode
        expect(rendered).to have_content(t('idv.form.zipcode'))
        expect(rendered).to have_content(pii[:identity_doc_zipcode])
      end

      it 'renders the address section' do
        # Heading
        expect(rendered).to have_content(t('headings.residential_address'))
        # address 1
        expect(rendered).to have_content(t('idv.form.address1'))
        expect(rendered).to have_content(pii[:address1])
        # address 2
        expect(rendered).to have_content(t('idv.form.address2'))
        expect(rendered).to have_content(pii[:address2])
        # address city
        expect(rendered).to have_content(t('idv.form.city'))
        expect(rendered).to have_content(pii[:city])
        # address state
        expect(rendered).to have_content(t('idv.form.state'))
        expect(rendered).to have_content(pii[:state])
        # address zipcode
        expect(rendered).to have_content(t('idv.form.zipcode'))
        expect(rendered).to have_content(pii[:zipcode])
      end

      it 'renders the ssn section' do
        # Heading
        expect(rendered).to have_content(t('headings.ssn'))
        # SSN
        expect(rendered).to have_content(t('idv.form.ssn'))
        expect(rendered).to have_content(SsnFormatter.format_masked(pii[:ssn]))
      end

      it 'does not render the passport section' do
        expect(rendered).to_not have_content(t('in_person_proofing.form.verify_info.passport'))
      end
    end

    context 'When the user is in the passport flow' do
      let(:passport_pii) do
        {
          passport_surname: Faker::Name.last_name,
          passport_first_name: Faker::Name.first_name,
          passport_dob: Faker::Date.in_date_period(year: 1985).to_s,
          passport_number: Faker::Number.number(digits: 9).to_s,
          passport_expiration: Faker::Date.in_date_period(year: Time.zone.now.year + 1),
        }
      end

      let(:pii) { { **passport_pii, **address_pii, **ssn_pii } }
      let(:enrollment) { build(:in_person_enrollment, :passport_book) }

      subject(:rendered) do
        render template: 'idv/in_person/verify_info/show'
      end

      before do
        assign(:presenter, Idv::InPerson::VerifyInfoPresenter.new(enrollment: enrollment))
        assign(:pii, pii)
        assign(:ssn, pii[:ssn])
      end

      it 'renders the passport section' do
        # Heading
        expect(rendered).to have_content(t('in_person_proofing.form.verify_info.passport'))
        # Surname
        expect(rendered).to have_content(t('in_person_proofing.form.passport.surname'))
        expect(rendered).to have_content(pii[:passport_surname])
        # First Name
        expect(rendered).to have_content(t('in_person_proofing.form.passport.first_name'))
        expect(rendered).to have_content(pii[:passport_first_name])
        # Date of Birth
        expect(rendered).to have_content(t('in_person_proofing.form.passport.dob'))
        expect(rendered).to have_content(
          I18n.l(Date.parse(pii[:passport_dob]), format: I18n.t('time.formats.event_date')),
        )
      end

      it 'renders the address section' do
        # Heading
        expect(rendered).to have_content(t('headings.residential_address'))
        # address 1
        expect(rendered).to have_content(t('idv.form.address1'))
        expect(rendered).to have_content(pii[:address1])
        # address 2
        expect(rendered).to have_content(t('idv.form.address2'))
        expect(rendered).to have_content(pii[:address2])
        # address city
        expect(rendered).to have_content(t('idv.form.city'))
        expect(rendered).to have_content(pii[:city])
        # address state
        expect(rendered).to have_content(t('idv.form.state'))
        expect(rendered).to have_content(pii[:state])
        # address zipcode
        expect(rendered).to have_content(t('idv.form.zipcode'))
        expect(rendered).to have_content(pii[:zipcode])
      end

      it 'renders the ssn section' do
        # Heading
        expect(rendered).to have_content(t('headings.ssn'))
        # SSN
        expect(rendered).to have_content(t('idv.form.ssn'))
        expect(rendered).to have_content(SsnFormatter.format_masked(pii[:ssn]))
      end

      it 'does not render the state-id section' do
        expect(rendered).to_not have_content(t('headings.state_id'))
      end
    end
  end
end
