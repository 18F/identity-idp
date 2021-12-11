require 'rails_helper'

describe WebauthnVisitForm do
  let(:subject) { WebauthnVisitForm.new }

  describe '#submit' do
    it 'returns FormResponse with success: true if there are no errors' do
      params = {}

      expect(subject.submit(params).to_h).to eq(
        success: true,
        errors: {},
        platform_authenticator: false,
      )
    end

    context 'when there are errors' do
      it 'returns FormResponse with success: false with InvalidStateError' do
        params = { error: 'InvalidStateError' }
        errors = { InvalidStateError: [I18n.t('errors.webauthn_setup.already_registered')] }

        expect(subject.submit(params).to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
        )
      end

      it 'returns FormResponse with success: false with NotSupportedError' do
        params = { error: 'NotSupportedError' }
        errors = { NotSupportedError: [I18n.t('errors.webauthn_setup.not_supported')] }

        expect(subject.submit(params).to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
        )
      end

      it 'returns FormResponse with success: false with an unrecognized error' do
        params = { error: 'foo' }
        errors = { foo: [I18n.t('errors.webauthn_setup.general_error')] }

        expect(subject.submit(params).to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
        )
      end
    end
  end
end
