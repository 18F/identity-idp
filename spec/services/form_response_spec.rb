require 'rails_helper'

RSpec.describe FormResponse do
  let(:success) { true }
  let(:errors) { {} }
  subject(:form_response) { FormResponse.new(success:, errors:) }

  describe '#success?' do
    context 'when the success argument is true' do
      it 'returns true' do
        response = FormResponse.new(success: true, errors: {})

        expect(response.success?).to eq true
      end
    end

    context 'when the success argument is false' do
      it 'returns false' do
        response = FormResponse.new(success: false, errors: {})

        expect(response.success?).to eq false
      end
    end
  end

  describe '#errors' do
    context 'initialized with hash' do
      it 'returns the value of the errors argument' do
        errors = { foo: 'bar' }
        response = FormResponse.new(success: true, errors: errors)

        expect(response.errors).to eq errors
      end
    end

    context 'initialized with ActiveModel::Errors' do
      it 'returns the messages value of the errors argument' do
        errors = ActiveModel::Errors.new(build_stubbed(:user))
        errors.add(:email_language, :blank, message: 'Language cannot be blank')
        response = FormResponse.new(success: false, errors: errors)

        expect(response.errors).to eq errors.messages
      end
    end
  end

  describe '#merge' do
    it 'merges the extra analytics' do
      response1 = FormResponse.new(success: true, errors: {}, extra: { step: 'foo', order: [1, 2] })
      response2 = DocAuth::Response.new(
        success: true,
        extra: { is_fallback_link: true, order: [2, 1] },
      )

      combined_response = response1.merge(response2)
      expect(combined_response.extra).to eq({ step: 'foo', is_fallback_link: true, order: [2, 1] })
    end

    it 'merges errors' do
      response1 = FormResponse.new(success: false, errors: { front: 'error' })
      response2 = DocAuth::Response.new(success: true, errors: { back: 'error' })

      combined_response = response1.merge(response2)
      expect(combined_response.errors).to eq(front: 'error', back: 'error')
    end

    it 'merges multiple errors for key' do
      response1 = FormResponse.new(success: false, errors: { front: 'front-error-1' })
      response2 = DocAuth::Response.new(success: true, errors: { front: ['front-error-2'] })

      combined_response = response1.merge(response2)
      expect(combined_response.errors).to eq(front: ['front-error-1', 'front-error-2'])
    end

    it 'merges error details' do
      errors1 = ActiveModel::Errors.new(build_stubbed(:user))
      errors1.add(:email_language, :blank, message: 'Language cannot be blank')
      errors2 = ActiveModel::Errors.new(build_stubbed(:user))
      errors2.add(:email_language, :invalid, message: 'Language is not valid')

      response1 = FormResponse.new(success: false, errors: errors1)
      response2 = FormResponse.new(success: false, errors: errors2)

      combined_response = response1.merge(response2)
      expect(combined_response.to_h[:error_details]).to eq(
        email_language: { blank: true, invalid: true },
      )
    end

    it 'merges hash and ActiveModel::Errors' do
      errors1 = ActiveModel::Errors.new(build_stubbed(:user))
      errors1.add(:email_language, :blank, message: 'Language cannot be blank')
      errors2 = { email_language: 'Language is not valid' }

      response1 = FormResponse.new(success: false, errors: errors1)
      response2 = FormResponse.new(success: false, errors: errors2)

      combined_response = response1.merge(response2)
      expect(combined_response.errors).to eq(
        email_language: ['Language cannot be blank', 'Language is not valid'],
      )
      expect(combined_response.to_h[:error_details]).to eq(email_language: { blank: true })
    end

    it 'returns true if one is false and one is true' do
      response1 = FormResponse.new(success: false, errors: {})
      response2 = DocAuth::Response.new(success: true)

      combined_response = response1.merge(response2)
      expect(combined_response.success?).to eq(false)
    end
  end

  describe '#first_error_message' do
    let(:key) { nil }
    subject(:first_error_message) { form_response.first_error_message(*[key].compact) }

    context 'with no errors' do
      let(:errors) { {} }

      it { expect(first_error_message).to be_nil }
    end

    context 'with errors' do
      let(:errors) { { email: ['invalid', 'too_short'], language: ['blank'] } }

      context 'without specified key' do
        let(:key) { nil }

        it 'returns the first error of the first field' do
          expect(first_error_message).to eq('invalid')
        end
      end

      context 'with specified key' do
        let(:key) { :language }

        it 'returns the first error of the specified field' do
          expect(first_error_message).to eq('blank')
        end
      end
    end
  end

  describe '#to_h' do
    context 'when the extra argument is nil' do
      it 'returns a hash with success and errors keys' do
        errors = { foo: 'bar' }
        response = FormResponse.new(success: true, errors: errors)
        response_hash = {
          success: true,
          errors: errors,
        }

        expect(response.to_h).to eq response_hash
      end
    end

    context 'when the extra argument is present' do
      it 'returns a hash with success and errors keys, and any keys from the extra hash' do
        errors = { foo: 'bar' }
        extra = { user_id: 1, context: 'confirmation' }
        response = FormResponse.new(success: true, errors: errors, extra: extra)
        response_hash = {
          success: true,
          errors: errors,
          user_id: 1,
          context: 'confirmation',
        }

        expect(response.to_h).to eq response_hash
      end
    end

    context 'when errors is an ActiveModel::Errors' do
      it 'returns a hash with success and error_details keys' do
        errors = ActiveModel::Errors.new(build_stubbed(:user))
        errors.add(:email_language, :blank, message: 'Language cannot be blank')
        response = FormResponse.new(success: false, errors: errors)
        response_hash = {
          success: false,
          error_details: {
            email_language: { blank: true },
          },
        }

        expect(response.to_h).to eq response_hash
      end

      context 'without error type' do
        it 'falls back to message as key for details' do
          errors = ActiveModel::Errors.new(build_stubbed(:user))
          errors.add(:email_language, :blank)
          response = FormResponse.new(success: false, errors: errors)
          response_hash = {
            success: false,
            error_details: {
              email_language: { blank: true },
            },
          }

          expect(response.to_h).to eq response_hash
        end
      end

      it 'omits details if errors are empty' do
        errors = ActiveModel::Errors.new(build_stubbed(:user))
        response = FormResponse.new(success: true, errors: errors)

        expect(response.to_h).to eq(success: true)
      end

      it 'omits details if merged errors are empty' do
        errors = ActiveModel::Errors.new(build_stubbed(:user))
        response1 = FormResponse.new(success: true, errors: errors)
        response2 = FormResponse.new(success: true, errors: errors)
        combined_response = response1.merge(response2)

        expect(combined_response.to_h).to eq(success: true)
      end

      context 'with error detail symbol defined as type option on error' do
        it 'returns a hash with success and error_details keys' do
          errors = ActiveModel::Errors.new(build_stubbed(:user))
          errors.add(:email_language, 'Language cannot be blank', type: :blank)
          response = FormResponse.new(success: false, errors: errors)
          response_hash = {
            success: false,
            error_details: {
              email_language: { blank: true },
            },
          }

          expect(response.to_h).to eq response_hash
        end
      end

      context 'with serialize_error_details_only' do
        it 'excludes errors from the hash' do
          errors = ActiveModel::Errors.new(build_stubbed(:user))
          errors.add(:email_language, :blank, message: 'Language cannot be blank')
          response = FormResponse.new(
            success: false,
            errors: errors,
            serialize_error_details_only: true,
          )

          expect(response.to_h).to eq(
            success: false,
            error_details: {
              email_language: { blank: true },
            },
          )
        end
      end
    end
  end

  describe '#to_hash' do
    it 'allows for splatting response as alias of #to_h' do
      errors = ActiveModel::Errors.new(build_stubbed(:user))
      errors.add(:email_language, :blank, message: 'Language cannot be blank')
      response = FormResponse.new(success: false, errors:, serialize_error_details_only: true)

      expect(**response).to eq(
        success: false,
        error_details: {
          email_language: { blank: true },
        },
      )
    end
  end

  describe '#extra' do
    it 'returns the extra hash' do
      extra = { foo: 'bar' }
      response = FormResponse.new(success: true, errors: {}, extra: extra)

      expect(response.extra).to eq extra
    end
  end
end
