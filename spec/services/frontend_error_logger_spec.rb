require 'rails_helper'

RSpec.describe FrontendErrorLogger do
  describe '.track_event' do
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
          },
        },
      )

      FrontendErrorLogger.track_error(
        name: 'name',
        message: 'message',
        stack: 'stack',
        filename: 'filename.js',
      )
    end

    context 'with filename other than js' do
      it 'notices an expected error to NewRelic with custom parameters' do
        expect(NewRelic::Agent).not_to receive(:notice_error)

        FrontendErrorLogger.track_error(
          name: 'name',
          message: 'message',
          stack: 'stack',
          filename: 'filename',
        )
      end
    end
  end
end
