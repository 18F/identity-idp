require 'rails_helper'

RSpec.describe Voice::OtpController do
  describe '#show' do
    subject(:action) { get :show, code: code, repeat_count: repeat_count, format: :xml }
    let(:code) { nil }
    let(:repeat_count) { nil }

    context 'without a code in the URL' do
      let(:code) { nil }

      it 'cannot route to the controller' do
        expect { action }.to raise_error(ActionController::UrlGenerationError)
      end
    end

    context 'with a blank code in the URL' do
      let(:code) { '' }

      it 'renders a blank 400' do
        action

        expect(response).to be_bad_request
        expect(response.body).to be_empty
      end
    end

    context 'with a code in the URL' do
      render_views

      let(:code) { 1234 }

      it 'tells Twilio to <Say> the code with pauses in between' do
        action

        doc = Nokogiri::XML(response.body)
        say = doc.css('Say').first
        expect(say.text).to include('1, 2, 3, 4,')
      end

      it 'has a <Gather> with instructions to repeat with a repeat_count' do
        action

        doc = Nokogiri::XML(response.body)
        gather = doc.css('Gather').first

        expect(gather['action']).to include('repeat_count=4')
      end

      context 'when repeat_count counts down to 1' do
        let(:repeat_count) { 1 }

        it 'does not have a <Gather> in the response' do
          action

          doc = Nokogiri::XML(response.body)
          expect(doc.css('Gather')).to be_empty
        end
      end
    end
  end
end
