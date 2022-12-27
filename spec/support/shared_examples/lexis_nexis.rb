shared_examples 'a lexisnexis proofer' do
  let(:verification_status) { 'passed' }
  let(:conversation_id) { 'foo' }
  let(:reference) { SecureRandom.uuid }
  let(:verification_errors) { {} }
  let(:result) { Proofing::Result.new }

  before do
    response = instance_double(Proofing::LexisNexis::Response)
    allow(response).to receive(:verification_status).and_return(verification_status)
    allow(response).to receive(:conversation_id).and_return(conversation_id)
    allow(response).to receive(:reference).and_return(reference)
    allow(response).to receive(:verification_errors).and_return(verification_errors)

    allow(verification_request).to receive(:send).and_return(response)
    allow(verification_request.class).to receive(:new).
      with(applicant: applicant, config: kind_of(Proofing::LexisNexis::Ddp::Proofer::Config)).
      and_return(verification_request)
  end

  describe '#proof_applicant' do
    context 'when proofing succeeds' do
      it 'results in a successful result' do
        result = subject.proof(applicant)

        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
        expect(result.transaction_id).to eq(conversation_id)
        expect(result.reference).to eq(reference)
      end
    end

    context 'when proofing fails' do
      let(:verification_status) { 'failed' }
      let(:verification_errors) do
        { base: 'test error', Discovery: 'another test error' }
      end

      it 'results in an unsuccessful result' do
        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(
          base: ['test error'],
          Discovery: ['another test error'],
        )
        expect(result.transaction_id).to eq(conversation_id)
        expect(result.reference).to eq(reference)
      end
    end
  end
end

shared_examples 'a lexisnexis request' do |basic_auth: true|
  describe '#http_headers' do
    it 'contains the content type' do
      expect(subject.headers).to include('Content-Type' => 'application/json')
    end
  end

  describe '#send' do
    if basic_auth
      it 'includes the basic auth header' do
        credentials = Base64.strict_encode64('test_username:test_password')
        expected_value = "Basic #{credentials}"

        stub_request(:post, subject.url).
          to_return(status: 200, body: response_body)

        subject.send

        expect(a_request(:post, subject.url).with(headers: { 'Authorization' => expected_value })).
          to have_been_requested
      end
    end

    it 'returns a response object initialized with the http response' do
      stub_request(:post, subject.url).
        to_return(status: 200, body: response_body)

      ln_response = subject.send
      expect(ln_response).to be_a(Proofing::LexisNexis::Response)
      expect(ln_response.response.status).to eq 200
      expect(ln_response.response.body).to eq response_body
      expect(ln_response.conversation_id).to be_a(String)
      expect(ln_response.reference).to be_a(String)
      expect(ln_response.verification_status).to be_a(String)
      expect(ln_response.verification_errors).to be_a(Hash)
    end
  end
end
