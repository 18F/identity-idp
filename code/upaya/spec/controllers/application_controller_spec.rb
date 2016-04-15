describe ApplicationController do
  describe 'handling InvalidAuthenticityToken exceptions' do
    controller do
      def index
        fail ActionController::InvalidAuthenticityToken
      end
    end

    it 'redirects to the sign in page' do
      get :index

      expect(response).to redirect_to(root_url)
    end

    it 'write to Rails log' do
      expect(Rails.logger).
        to receive(:info).with('Rescuing InvalidAuthenticityToken')

      get :index
    end

    it 'signs user out' do
      sign_in_as_user
      expect(subject.current_user).to be_present

      get :index

      expect(response).to redirect_to(root_url)
      expect(subject.current_user).to be_nil
    end
  end

  describe '#append_info_to_payload' do
    let(:payload) { {} }

    it 'adds time, user_agent and ip to the lograge output' do
      Timecop.freeze(Time.current) do
        subject.append_info_to_payload(payload)

        expect(payload.keys).to eq [:time, :user_agent, :ip]
        expect(payload.values).to eq [Time.current, request.user_agent, request.remote_ip]
      end
    end
  end
end
