shared_examples 'a recurring job controller' do |api_token|
  context 'with no token' do
    it 'returns unauthorized' do
      post :create

      expect(response.status).to eq 401
    end
  end

  context 'with an invalid token' do
    it 'returns unauthorized' do
      request.headers['X-API-AUTH-TOKEN'] = 'invalid'

      post :create

      expect(response.status).to eq 401
    end
  end

  context 'with a valid token' do
    it 'returns a succesful response' do
      request.headers['X-API-AUTH-TOKEN'] = api_token

      post :create

      expect(response.status).to eq 200
    end
  end
end
