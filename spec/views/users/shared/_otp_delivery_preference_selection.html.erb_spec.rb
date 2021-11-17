require 'rails_helper'

describe 'users/shared/_otp_delivery_preference_selection.html.erb' do
  let(:user) { build_stubbed(:user) }

  subject(:rendered) do
    render 'users/shared/otp_delivery_preference_selection', form_obj: NewPhoneForm.new(user)
  end

  it 'renders enabled sms option' do
    expect(rendered).to have_field('new_phone_form_otp_delivery_preference_sms', disabled: false)
  end

  context 'sms vendor outage' do
    before do
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).and_return(false)
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).with(:sms).and_return(true)
    end

    it 'renders disabled sms option' do
      expect(rendered).to have_field('new_phone_form_otp_delivery_preference_sms', disabled: true)
    end
  end

  it 'renders enabled voice option' do
    expect(rendered).to have_field('new_phone_form_otp_delivery_preference_voice', disabled: false)
  end

  context 'voice vendor outage' do
    before do
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).and_return(false)
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).with(:voice).and_return(true)
    end

    it 'renders disabled voice option' do
      expect(rendered).to have_field('new_phone_form_otp_delivery_preference_voice', disabled: true)
    end
  end
end
