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

  let(:state_id_pii) do
    {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      dob: Faker::Date.in_date_period(year: 1985).to_s,
      state_id_jurisdiction: Faker::Address.state_abbr,
      state_id_number: Faker::Number.number(digits: 6).to_s,
      state_id_expiration: Faker::Date.in_date_period(year: Time.zone.now.year + 1).to_s,
      identity_doc_address1: Faker::Address.street_address,
      identity_doc_address2: Faker::Address.secondary_address,
      identity_doc_city: Faker::Address.city,
      identity_doc_address_state: Faker::Address.state_abbr,
      identity_doc_zipcode: Faker::Address.zip,
    }
  end

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
    assign(
      :presenter,
      Idv::InPerson::VerifyInfoPresenter.new(enrollment: build(:in_person_enrollment, :state_id)),
    )
    assign(:pii, { **state_id_pii, **address_pii, **ssn_pii })
    assign(:ssn, ssn_pii[:ssn])
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.idv.verify_info'))

    render template: 'idv/in_person/verify_info/show'
  end

  context 'in the default layout' do
    it 'does not render the NDS form-page card' do
      render template: 'idv/in_person/verify_info/show'

      expect(rendered).to_not have_selector('.auth--form-page')
    end

    context 'When the user is in the state_id flow' do
      let(:state_id_pii) do
        {
          first_name: Faker::Name.first_name,
          last_name: Faker::Name.last_name,
          dob: Faker::Date.in_date_period(year: 1985).to_s,
          state_id_jurisdiction: Faker::Address.state_abbr,
          state_id_number: Faker::Number.number(digits: 6).to_s,
          state_id_expiration: Faker::Date.in_date_period(year: Time.zone.now.year + 1).to_s,
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
        # State ID expiration date
        expect(rendered).to have_content(t('in_person_proofing.form.state_id.expiration_date'))
        expect(rendered).to have_content(
          I18n.l(Date.parse(pii[:state_id_expiration]), format: I18n.t('time.formats.event_date')),
        )
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

      it 'renders the address update link with click observer' do
        expect(rendered).to have_css(
          "lg-click-observer[event-name='" \
          "idv_in_person_proofing_verify_info_update_address_button_clicked']",
        )
      end

      it 'renders the ssn section' do
        # Heading
        expect(rendered).to have_content(t('headings.ssn'))
        # SSN
        expect(rendered).to have_content(t('idv.form.ssn'))
        expect(rendered).to have_content(SsnFormatter.format_masked(pii[:ssn]))
      end

      it 'renders the ssn update link with click observer' do
        expect(rendered).to have_css(
          "lg-click-observer[event-name='" \
          "idv_in_person_proofing_verify_info_update_ssn_button_clicked']",
        )
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

  context 'in the NDS layout' do
    subject(:rendered) do
      render template: 'idv/in_person/verify_info/show'
    end

    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the verify heading and stepper' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('h1', text: t('headings.verify'))
      expect(rendered).to_not have_content(
        t('in_person_proofing.form.verify_info.passport_intro_text'),
      )

      progress = Capybara.string(view.content_for(:nds_header_progress))
      expect(progress).to have_css('.progress__step-counter', text: '7 / 12')
    end

    it 'summarizes the state ID, ID address, residential address and SSN' do
      expect(rendered).to have_css('h2', text: t('headings.state_id'))
      expect(rendered).to have_css('.nds-summary__label', text: t('idv.form.issuing_state'))
      expect(rendered).to have_content(state_id_pii[:state_id_number])
      expect(rendered).to have_content(state_id_pii[:identity_doc_address1])
      expect(rendered).to have_css('.nds-summary__label', text: t('headings.residential_address'))
      expect(rendered).to have_content(address_pii[:address1])
      expect(rendered).to have_content(
        t(
          'idv.accessible_labels.masked_ssn',
          first_number: ssn_pii[:ssn][0], last_number: ssn_pii[:ssn][-1],
        ),
      )
      expect(rendered).to_not have_content(t('in_person_proofing.form.verify_info.passport'))
    end

    it 'keeps the edit links and their click events' do
      address_event = 'idv_in_person_proofing_verify_info_update_address_button_clicked'
      ssn_event = 'idv_in_person_proofing_verify_info_update_ssn_button_clicked'
      expect(rendered).to have_css(
        "lg-click-observer[event-name='#{address_event}'] " \
        "a[href='#{idv_in_person_address_url}']" \
        "[aria-label='#{t('idv.buttons.change_address_label')}']",
      )
      expect(rendered).to have_css(
        "lg-click-observer[event-name='#{ssn_event}'] " \
        "a[href='#{idv_in_person_ssn_url}'][aria-label='#{t('idv.buttons.change_ssn_label')}']",
      )
    end

    it 'puts Continue to the verify info path with the wait polling and a cancel link' do
      expect(rendered).to have_css(
        "form[action='#{idv_in_person_verify_info_path}'][data-form-steps-wait]" \
        "[data-wait-step-path='#{idv_in_person_verify_info_path}']",
      )
      expect(rendered).to have_button(t('forms.buttons.continue'))
      expect(rendered).to have_css('#form-steps-wait-alert', visible: :all)
      expect(rendered).to have_link(t('links.cancel'), href: idv_cancel_path(step: 'verify'))
    end

    context 'in the passport flow' do
      let(:passport_pii) do
        {
          passport_surname: Faker::Name.last_name,
          passport_first_name: Faker::Name.first_name,
          passport_dob: Faker::Date.in_date_period(year: 1985).to_s,
        }
      end

      before do
        assign(
          :presenter,
          Idv::InPerson::VerifyInfoPresenter.new(
            enrollment: build(:in_person_enrollment, :passport_book),
          ),
        )
        assign(:pii, { **passport_pii, **address_pii, **ssn_pii })
      end

      it 'renders the passport intro and summary instead of the state ID' do
        expect(rendered).to have_content(
          t('in_person_proofing.form.verify_info.passport_intro_text'),
        )
        expect(rendered).to have_css('h2', text: t('in_person_proofing.form.verify_info.passport'))
        expect(rendered).to have_content(passport_pii[:passport_surname])
        expect(rendered).to_not have_css('h2', text: t('headings.state_id'))
      end
    end
  end
end
