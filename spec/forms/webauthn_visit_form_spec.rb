require 'rails_helper'

describe WebauthnVisitForm do
  let(:subject) { WebauthnVisitForm.new }

  describe '#submit' do
    it 'returns FormResponse with success: true if there are no errors' do
      result = instance_double(FormResponse)
      params = {}

      expect(FormResponse).to receive(:new).
        with(success: true, errors: {}).and_return(result)
      expect(subject.submit(params)).to eq result
    end

    context 'when there are errors' do
      it 'returns FormResponse with success: false with InvalidStateError' do
        result = instance_double(FormResponse)
        params = { error: 'InvalidStateError' }
        errors = { InvalidStateError: [I18n.t('errors.webauthn_setup.already_registered')] }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors).and_return(result)
        expect(subject.submit(params)).to eq result
      end

      it 'returns FormResponse with success: false with NotSupportedError' do
        result = instance_double(FormResponse)
        params = { error: 'NotSupportedError' }
        errors = { NotSupportedError: [I18n.t('errors.webauthn_setup.not_supported')] }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors).and_return(result)
        expect(subject.submit(params)).to eq result
      end

      it 'returns FormResponse with success: false with an unrecognized error' do
        result = instance_double(FormResponse)
        params = { error: 'foo' }
        errors = { foo: [I18n.t('errors.webauthn_setup.general_error')] }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors).and_return(result)
        expect(subject.submit(params)).to eq result
      end
    end
  end
end
