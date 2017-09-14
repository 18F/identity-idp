require 'rails_helper'

describe Aws::SES::Base do
  let(:mail) do
    Mail.new(
      to: 'asdf@example.com',
      cc: 'ghjk@example.com',
      body: 'asdf1234'
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
        }
      )
    end

    it 'sets the message id on the mail argument' do
      subject.deliver!(mail)
      expect(mail.message_id).to eq('123abc@email.amazonses.com')
    end
  end
end
