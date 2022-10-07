require 'rails_helper'

describe EditPhoneForm do
  include Shoulda::Matchers::ActiveModel

  let(:user) { create(:user, :signed_up) }
  let(:phone_configuration) { user.phone_configurations.first }
  let(:params) do
    {
      delivery_preference: 'voice',
    }
  end

  subject { described_class.new(user, phone_configuration) }

  describe '#submit' do
    context 'when delivery_preference is not voice or sms' do
      let(:params) do
        {
          delivery_preference: 'foo',
        }
      end

      it 'is invalid' do
        result = subject.submit(params)

        expect(result.success?).to eq(false)
        expect(result.errors[:delivery_preference].first).
          to eq 'is not included in the list'
      end
    end

    context 'when delivery_preference is valid' do
      it 'updates the phone number' do
        expect(phone_configuration.delivery_preference).to eq('sms')

        result = subject.submit(params)
        expect(result.success?).to eq(true)

        expect(phone_configuration.reload.delivery_preference).to eq('voice')
      end

      it 'includes delivery_preference in the form response extra' do
        result = subject.submit(params)

        expect(result.extra).to eq(
          delivery_preference: params[:delivery_preference],
          make_default_number: true,
          phone_configuration_id: phone_configuration.id,
        )
      end
    end

    context 'when delivery_preference is empty' do
      let(:params) do
        {
          delivery_preference: '',
        }
      end

      it 'is invalid' do
        result = subject.submit(params)

        expect(result.success?).to eq(false)
        expect(result.errors[:delivery_preference].first).
          to eq 'is not included in the list'
      end
    end

    describe 'default phone selection' do
      before do
        create(:phone_configuration, user: user, made_default_at: Time.zone.now)
      end

      context 'when the make_default_number param is true' do
        let(:params) { super().merge(make_default_number: true) }

        it 'makes the phone configuration the default configuration' do
          expect(user.default_phone_configuration).to_not eq(phone_configuration)

          subject.submit(params)

          expect(user.default_phone_configuration).to eq(phone_configuration)
        end
      end

      context 'when the make_default_number param is false' do
        let(:params) { super().merge(make_default_number: false) }

        it 'does not make the phone configuration the default configuration' do
          expect(user.default_phone_configuration).to_not eq(phone_configuration)

          subject.submit(params)

          expect(user.default_phone_configuration).to_not eq(phone_configuration)
        end
      end

      context 'when the make_default_number param is not present' do
        it 'does not make the phone configuration the default configuration' do
          expect(user.default_phone_configuration).to_not eq(phone_configuration)

          subject.submit(params)

          expect(user.default_phone_configuration).to_not eq(phone_configuration)
        end
      end
    end
  end

  describe 'user has one number' do
    let(:user) { create(:user, :signed_up) }
    let(:phone_configuration) { user.phone_configurations.first }

    it 'recognizes it as the only method set up' do
      expect(user.default_phone_configuration).to eq(phone_configuration)
    end
  end
end
