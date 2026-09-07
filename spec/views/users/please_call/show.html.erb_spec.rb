require 'rails_helper'

RSpec.describe 'users/please_call/show.html.erb' do
  let(:nds_layout) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    render
  end

  it 'includes a message instructing them to call contact center' do
    expect(rendered).to have_text(
      strip_tags(
        t(
          'users.suspended_sign_in_account.contact_details',
          contact_number: IdentityConfig.store.idv_contact_phone_number,
        ),
      ),
    )
  end

  it 'display support code' do
    expect(rendered).to have_text(
      strip_tags(
        t(
          'users.suspended_sign_in_account.error_details',
          error_code: 'EFGHI',
        ),
      ),
    )
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the contact details in the card body' do
      expect(rendered).to have_css(
        '.auth__form-page-body p',
        text: strip_tags(
          t(
            'users.suspended_sign_in_account.contact_details',
            contact_number: IdentityConfig.store.idv_contact_phone_number,
          ),
        ),
      )
    end

    it 'links the contact number as a non-wrapping tel: link' do
      number = IdentityConfig.store.idv_contact_phone_number
      expect(rendered).to have_css(
        "a.text-no-wrap[href='tel:#{number.gsub(/\D/, '')}']",
        text: number,
      )
    end

    it 'renders the support code as an inline field readout within the sentence' do
      expect(rendered).to have_css(
        '.auth__form-page-body p',
        text: strip_tags(t('users.suspended_sign_in_account.error_details', error_code: 'EFGHI')),
      )
      expect(rendered).to have_css(
        'p .field-readout.field-readout--inline .field-readout__value',
        text: 'EFGHI',
      )
      expect(rendered).not_to have_css('lg-clipboard-button')
    end
  end
end
