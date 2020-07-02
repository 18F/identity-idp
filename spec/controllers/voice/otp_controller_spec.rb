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

    context 'with an invalid encrypted_code in the URL' do
      let(:encrypted_code) { '%25' }

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

      it 'includes a capitalized Response tag' do
        action

        doc = Nokogiri::XML(response.body)
        response = doc.css('Response').first

        expect(response).to be_present
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

      it 'includes the otp expiration in the message' do
        locale = :en # rubocop:disable Lint/UselessAssignment
        allow(Devise).to receive(:direct_otp_valid_for).and_return(4.minutes)

        action
        expect(response.body).to include('4 minutes')
      end

      let(:expected_xml) do
        <<~XML
<?xml version="1.0" encoding="utf-8" ?><Response><Say language="en">Hello! Your login.gov one time passcode is, 1, 2, 3, 4, again, your passcode is, 1, 2, 3, 4. This code expires in 10 minutes.</Say><Gather action="http://user:secret@www.example.com/api/voice/otp?encrypted_code=%7B%22v%22%3A1%2C%22adata%22%3A%22%22%2C%22ks%22%3A256%2C%22ct%22%3A%22a31jflU1SEV9nuRkwTQ1oQ%3D%3D%22%2C%22ts%22%3A96%2C%22mode%22%3A%22gcm%22%2C%22cipher%22%3A%22aes%22%2C%22iter%22%3A100000%2C%22iv%22%3A%22DF9MmigoP%2Bc5wctv%22%2C%22salt%22%3A%22rqj10u4Smb4%3D%22%7D&amp;repeat_count=4" numDigits="1"><Say language="en">Press 1 to repeat this message.</Say></Gather><Hangup /></Response>
        XML
      end

      it 'outputs the same XML as the slim file' do
        action
        expect(response.body).to eq(Nokogiri::XML(expected_xml).to_xml)
      end
    end
  end
end
