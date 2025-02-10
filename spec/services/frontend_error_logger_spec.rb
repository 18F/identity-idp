require 'rails_helper'

RSpec.describe FrontendErrorLogger do
  let(:valid) { true }

  before do
    allow_any_instance_of(FrontendErrorForm).to receive(:submit)
      .and_return(FormResponse.new(success: valid))
  end

  describe '.track_event' do
    let(:payload) { { name: 'name', message: 'message', stack: 'stack' } }
    subject(:result) { FrontendErrorLogger.track_error(**payload) }

    context 'with filename payload' do
      let(:payload) { super().merge(filename: 'filename.js') }

      it 'notices an expected error to NewRelic with custom parameters' do
        expect(NewRelic::Agent).to receive(:notice_error).with(
          kind_of(FrontendErrorLogger::FrontendError),
          expected: true,
          custom_params: {
            frontend_error: {
              name: 'name',
              message: 'message',
              stack: 'stack',
              filename: 'filename.js',
              error_id: nil,
            },
          },
        )

        result
      end
    end

    context 'with error id payload' do
      let(:payload) { super().merge(error_id: 'exampleId') }

      it 'notices an expected error to NewRelic with custom parameters' do
        expect(NewRelic::Agent).to receive(:notice_error).with(
          kind_of(FrontendErrorLogger::FrontendError),
          expected: true,
          custom_params: {
            frontend_error: {
              name: 'name',
              message: 'message',
              stack: 'stack',
              filename: nil,
              error_id: 'exampleId',
            },
          },
        )

        result
      end
    end

    context 'with unsuccessful validation of request parameters' do
      let(:valid) { false }

      it 'does not notice an error' do
        expect(NewRelic::Agent).not_to receive(:notice_error)

        FrontendErrorLogger.track_error(
          name: 'name',
          message: 'message',
          stack: 'stack',
          filename: 'filename.js',
        )
      end
    end
  end
end
