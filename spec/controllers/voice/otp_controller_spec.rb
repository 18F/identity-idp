require 'rails_helper'

RSpec.describe Voice::OtpController do
  describe '#show' do
    subject(:action) do
      get :show,
          params: { code: code, repeat_count: repeat_count, locale: locale },
          format: :xml
    end
    let(:code) { nil }
    let(:locale) { nil }
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

      it 'sets the lang attribute to english' do
        action

        doc = Nokogiri::XML(response.body)
        say = doc.css('Say').first

        expect(say[:language]).to eq('en')
      end

      context 'when the locale is in spanish' do
        let(:locale) { :es }

        it 'sets the lang attribute to english' do
          action

          doc = Nokogiri::XML(response.body)
          say = doc.css('Say').first

          expect(say[:language]).to eq('es')
        end

        it 'passes locale into the <Gather> action URL' do
          action

          doc = Nokogiri::XML(response.body)
          gather = doc.css('Gather').first

          params = URIService.params(gather[:action])
          expect(params[:locale]).to eq('es')
        end
      end

      context 'when the locale is in french' do
        let(:locale) { :fr }

        it 'sets the lang attribute to english' do
          action

          doc = Nokogiri::XML(response.body)
          say = doc.css('Say').first

          expect(say[:language]).to eq('fr')
        end

        it 'passes locale into the <Gather> action URL' do
          action

          doc = Nokogiri::XML(response.body)
          gather = doc.css('Gather').first

          params = URIService.params(gather[:action])
          expect(params[:locale]).to eq('fr')
        end
      end

      it 'has a <Gather> with instructions to repeat with a repeat_count' do
        action

        doc = Nokogiri::XML(response.body)
        gather = doc.css('Gather').first

        expect(gather[:action]).to include('repeat_count=4')
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
