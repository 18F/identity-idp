require 'rails_helper'

RSpec.describe Voice::OtpController do
  describe '#show' do
    subject(:action) do
      get :show,
          params: { encrypted_code: encrypted_code, repeat_count: repeat_count, locale: locale },
          format: :xml
    end
    let(:locale) { nil }
    let(:repeat_count) { nil }
    let(:cipher) { Gibberish::AES.new(Figaro.env.attribute_encryption_key) }

    context 'with a blank encrypted_code in the URL' do
      let(:encrypted_code) { '' }

      it 'renders a blank 400' do
        action

        expect(response).to be_bad_request
        expect(response.body).to be_empty
      end
    end

    context 'with an encrypted_code in the URL' do
      render_views

      let(:code) { '1234' }
      let(:encrypted_code) { cipher.encrypt(code) }

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

      it 'puts the encrypted code in the <Gather> action' do
        action

        doc = Nokogiri::XML(response.body)
        gather = doc.css('Gather').first
        params = URIService.params(gather[:action])

        expect(cipher.decrypt(params[:encrypted_code])).to eq(code)
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
