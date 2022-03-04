require 'rails_helper'

RSpec.describe AnalyticsEventsController do
  describe '#index' do
    subject(:action) { get :index }

    context 'when the JSON file exists' do
      let(:json_content) { { events: [] }.to_json }

      around do |ex|
        Tempfile.create do |json_file|
          @json_file = json_file
          json_file.rewind
          json_file << json_content
          json_file.close

          ex.run
        end
      end

      before do
        stub_const('AnalyticsEventsController::JSON_FILE', @json_file.path)
      end

      it 'renders the file' do
        action

        expect(response).to be_ok
        expect(response.body).to eq(json_content)
        expect(response.content_type).to eq('application/json')
      end
    end

    context 'when the JSON file does not exist' do
      it '404s' do
        action

        expect(response).to be_not_found
      end
    end
  end
end
