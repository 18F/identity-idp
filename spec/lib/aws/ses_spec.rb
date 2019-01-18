require 'rails_helper'

describe Aws::SES::Base do
  let(:mail) do
    Mail.new(
      to: 'asdf@example.com',
      cc: 'ghjk@example.com',
      body: 'asdf1234',
    )
  end
  let(:ses_response) do
    response = double
    allow(response).to receive(:message_id).and_return('123abc')
    response
  end
  let(:ses_client) { instance_double(Aws::SES::Client) }

  before do
    allow(ses_client).to receive(:send_raw_email).and_return(ses_response)
    allow(Aws::SES::Client).to receive(:new).and_return(ses_client)
  end

  describe '#deliver!' do
    it 'sends the message to the correct recipients' do
      raw_mail_data = mail.to_s

      subject.deliver!(mail)

      expect(ses_client).to have_received(:send_raw_email).with(
        raw_message: {
          data: raw_mail_data,
        },
      )
    end

    it 'sets the message id on the mail argument' do
      subject.deliver!(mail)
      expect(mail.message_id).to eq('123abc@email.amazonses.com')
    end

    it 'retries timed out requests' do
      allow(Figaro.env).to receive(:aws_ses_region_pool).and_return(nil)
      Aws::SES::Base.new.deliver!(mail)

      expect(Aws::SES::Client).to have_received(:new) do |options|
        expect(options[:retry_limit]).to eq 3
        expect(options.key?(:retry_backoff)).to eq true
      end
    end

    context 'with an ses region pool in the configuration' do
      before do
        allow(Figaro.env).to receive(:aws_ses_region_pool).
          and_return('{ "us-fake-1": 5, "us-phony-2": 95 }')
      end

      it 'should build a region pool if the region pool does not exist' do
        expected_pool = ['us-fake-1'] * 5 + ['us-phony-2'] * 95
        described_class.region_pool = nil
        subject.deliver!(mail)

        expect(described_class.region_pool).to eq(expected_pool)
      end

      it 'should not build a new region pool if one does exist' do
        expected_pool = ['us-fake-1', 'us-phony-2']
        described_class.region_pool = expected_pool
        subject.deliver!(mail)

        expect(described_class.region_pool).to eq(expected_pool)
      end

      it 'should initialize the AWS client with a region selected from the region pool' do
        described_class.region_pool = []

        allow(described_class.region_pool).to receive(:sample).and_return('us-fake-1')
        described_class.new.deliver!(mail)

        expect(Aws::SES::Client).to have_received(:new) do |options|
          expect(options[:region]).to eq 'us-fake-1'
        end
      end
    end

    context 'without an ses region in the configuration' do
      it 'should initialize the AWS client without a region argument' do
        allow(Figaro.env).to receive(:aws_ses_region_pool).and_return(nil)
        Aws::SES::Base.new.deliver!(mail)

        allow(Figaro.env).to receive(:aws_ses_region_pool).and_return('')
        Aws::SES::Base.new.deliver!(mail)

        expect(Aws::SES::Client).to have_received(:new).with(hash_excluding(:region)).twice
      end
    end
  end
end
