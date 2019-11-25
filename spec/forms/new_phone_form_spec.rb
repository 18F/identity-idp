require 'rails_helper'

describe NewPhoneForm do
  include Shoulda::Matchers::ActiveModel

  let(:user) { build(:user, :signed_up) }
  let(:params) do
    {
      phone: '703-555-5000',
      international_code: 'US',
      otp_delivery_preference: 'sms',
    }
  end
  subject { NewPhoneForm.new(user) }

  it_behaves_like 'a phone form'
  it_behaves_like 'an international phone form'
  it_behaves_like 'an otp delivery preference form'

  describe '#submit' do
    context 'when phone is valid' do
      it 'is valid' do
        result = subject.submit(params)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end

      it 'includes otp preference in the form response extra' do
        result = subject.submit(params)

        expect(result.extra).to eq(
          otp_delivery_preference: params[:otp_delivery_preference],
        )
      end

      it 'does not update the user phone attribute' do
        user = create(:user)
        subject = NewPhoneForm.new(user)
        params[:phone] = '+1 504 444 1643'

        subject.submit(params)

        user.reload
        expect(MfaContext.new(user).phone_configurations).to be_empty
      end
    end

    it 'revokes the users rememder device sessions' do
      subject.submit(params)

      expect(user.reload.remember_device_revoked_at).to be_within(1.second).of(Time.zone.now)
    end
  end
end
