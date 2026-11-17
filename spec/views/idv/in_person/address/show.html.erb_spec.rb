require 'rails_helper'

RSpec.describe 'idv/in_person/address/show.html.erb' do
  let(:pii) { {} }
  let(:form) { Idv::InPerson::AddressForm.new }
  let(:updating_address) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:url_for).and_return(idv_in_person_address_path)
    assign(:presenter, Idv::InPerson::UspsFormPresenter.new)
  end

  subject(:rendered) do
    render template: 'idv/in_person/address/show', locals: { form:, pii:, updating_address: }
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('in_person_proofing.headings.address'))

    rendered
  end

  context 'in the default layout' do
    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end

    it 'renders the address form' do
      expect(rendered).to have_content(t('in_person_proofing.headings.address'))
      expect(rendered).to have_select('in_person_address[state]')
      expect(rendered).to have_field('in_person_address[address1]')
      expect(rendered).to have_button(t('forms.buttons.continue'))
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the address heading and stepper' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('h1', text: t('in_person_proofing.headings.address'))

      progress = Capybara.string(view.content_for(:nds_header_progress))
      expect(progress).to have_css('.progress__step-counter', text: '5 / 12')
    end

    it 'puts the same address fields to the same path' do
      expect(rendered).to have_css(
        "form[action='#{idv_in_person_address_path}'][data-nds-submit-gate]",
      )
      expect(rendered).to have_css('input[name="_method"][value="put"]', visible: :all)
      %w[address1 address2 city zipcode].each do |field|
        expect(rendered).to have_field("in_person_address[#{field}]")
      end
      expect(rendered).to have_select('in_person_address[state]')
      expect(rendered).to have_css('select.address-state-selector[required]')
      expect(rendered).to have_css('input.zipcode[pattern]')
      expect(rendered).to have_css('.puerto-rico-extras.display-none', visible: :all, count: 2)
    end

    it 'renders Continue and a cancel link' do
      expect(rendered).to have_css(
        '.auth__actions button[type=submit]',
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to have_link(t('links.cancel'), href: idv_cancel_path(step: 'address'))
    end

    context 'when updating the address' do
      let(:updating_address) { true }
      let(:pii) { { address1: '1 FAKE RD', city: 'GREAT FALLS', state: 'MT', zipcode: '59010' } }

      it 'renders the update heading, prefilled fields, Update and Back' do
        expect(rendered).to have_css('h1', text: t('in_person_proofing.headings.update_address'))
        expect(rendered).to have_field('in_person_address[address1]', with: '1 FAKE RD')
        expect(rendered).to have_select('in_person_address[state]', selected: 'Montana')
        expect(rendered).to have_button(t('forms.buttons.submit.update'))
        expect(rendered).to have_link(
          t('forms.buttons.back'),
          href: idv_in_person_verify_info_path,
        )
      end
    end

    context 'with a server-side field error' do
      before do
        form.errors.add(:city, 'Unsupported characters')
      end

      it 'shows the error on the field' do
        expect(rendered).to have_css('.usa-input__error--visible', text: 'Unsupported characters')
      end
    end

    context 'with a server-side state error' do
      before do
        form.errors.add(:state, 'Pick a state')
      end

      it 'labels the select visibly and ties the error to it' do
        expect(rendered).to have_css('label.usa-label[for="in_person_address_state"]')
        expect(rendered).to have_css(
          'select#in_person_address_state[aria-invalid="true"]' \
          '[aria-describedby="in_person_address_state_error"]',
        )
        expect(rendered).to have_css('#in_person_address_state_error', text: 'Pick a state')
      end
    end
  end
end
