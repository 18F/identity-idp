require 'rails_helper'

describe AddPhoneForm do
  include Shoulda::Matchers::ActiveModel

  let(:user) { create(:user, :signed_up) }
  let(:params) do
    {
      phone: '703-555-5000',
      international_code: 'US',
      otp_delivery_preference: 'sms',
    }
  end

  subject { described_class.new(user) }

  it_behaves_like 'a phone form'
  it_behaves_like 'an otp delivery preference form'

  describe 'phone validation' do
    it do
      should validate_inclusion_of(:international_code).
        in_array(PhoneNumberCapabilities::INTERNATIONAL_CODES.keys)
    end

    it 'validates that the number matches the requested international code' do
      params[:phone] = '123 123 1234'
      params[:international_code] = 'MA'
      result = subject.submit(params)

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to include(:phone)
    end
  end

  it 'is valid when the params are valid' do
    result = subject.submit(params)

    expect(result).to be_kind_of(FormResponse)
    expect(result.success?).to eq(true)
    expect(result.errors).to be_empty
    expect(result.extra).to eq(
      otp_delivery_preference: params[:otp_delivery_preference],
    )
  end

  it 'revokes the users rememder device sessions' do
    subject.submit(params)

    expect(user.reload.remember_device_revoked_at).to be_within(1.second).of(Time.zone.now)
  end

  it 'preserves the format of the submitted phone number if phone is invalid' do
    params[:phone] = '555-555-5000'
    params[:international_code] = 'MA'

    result = subject.submit(params)

    expect(result.success?).to eq(false)
    expect(subject.phone).to eq('555-555-5000')
  end
end
