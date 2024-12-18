require 'rails_helper'

RSpec.describe 'mailer_helper' do
  def mail_double(to:, subject:, body:)
    instance_double(
      Mail::Message,
      to:,
      subject:,
      text_part: instance_double(
        Mail::Part,
        decoded: body,
      ),
    )
  end

  let(:all_deliveries) do
    [
      mail_double(
        to: ['user@example.com'],
        subject: 'Test subject 1',
        body: 'Hello world!',
      ),
    ]
  end

  before do
    allow(ActionMailer::Base).to receive(:deliveries).and_return(all_deliveries)
  end

  describe '#expect_delivered_email' do
    context 'when searching by to' do
      context 'and found' do
        it 'does not raise' do
          expect do
            expect_delivered_email(to: 'user@example.com')
          end.not_to raise_error
        end
      end
      context 'and not found' do
        it 'raises an appropriate error' do
          expect do
            expect_delivered_email(to: 'otheruser@example.com')
          end.to raise_error(
            satisfy do |err|
              expect(err.message).to eql(
                <<~END,
                  Unable to find email matching args:
                    to: otheruser@example.com
                    subject: 
                    body: 
                  Sent mails:
                    - To:      [\"user@example.com\"] (did not match)
                      Subject: Test subject 1
                END
              )
            end,
          )
        end
      end
    end

    context 'when searching by subject' do
      context 'and found' do
        it 'does not raise' do
          expect do
            expect_delivered_email(subject: 'Test subject 1')
          end.not_to raise_error
        end
        context 'and not found' do
          it 'raises an appropriate error' do
            expect do
              expect_delivered_email(subject: 'Another unrelated subject')
            end.to raise_error(
              satisfy do |err|
                expect(err.message).to eql(
                  <<~END,
                    Unable to find email matching args:
                      to: 
                      subject: Another unrelated subject
                      body: 
                    Sent mails:
                      - To:      [\"user@example.com\"]
                        Subject: Test subject 1 (did not match)
                  END
                )
              end,
            )
          end
        end
      end
    end

    context 'when searching by body' do
      context 'with string' do
        context 'when found' do
          it 'does not raise' do
            expect do
              expect_delivered_email(
                body: 'Hello',
              )
            end.not_to raise_error
          end
        end
        context 'and not found' do
          it 'raises an appropriate error' do
            expect do
              expect_delivered_email(body: 'Hellow')
            end.to raise_error(
              satisfy do |err|
                expect(err.message).to eql(
                  <<~END,
                    Unable to find email matching args:
                      to: 
                      subject: 
                      body: Hellow
                    Sent mails:
                      - To:      [\"user@example.com\"]
                        Subject: Test subject 1
                        Body:
                          - "Hellow" (not found)
                  END
                )
              end,
            )
          end
        end
      end
      context 'with array' do
        context 'when found' do
          it 'does not raise' do
            expect do
              expect_delivered_email(
                body: ['Hello', 'world'],
              )
            end.not_to raise_error
          end
        end
        context 'and not found' do
          it 'raises an appropriate error' do
            expect do
              expect_delivered_email(body: ['Hellow', 'world'])
            end.to raise_error(
              satisfy do |err|
                expect(err.message).to eql(
                  <<~END,
                    Unable to find email matching args:
                      to: 
                      subject: 
                      body: ["Hellow", "world"]
                    Sent mails:
                      - To:      [\"user@example.com\"]
                        Subject: Test subject 1
                        Body:
                          - "Hellow" (not found)
                          - "world" (found)
                  END
                )
              end,
            )
          end
        end
      end
    end

    context 'when searching by to + subject + body' do
      context 'and found' do
        it 'does not raise' do
          expect do
            expect_delivered_email(
              to: 'user@example.com',
              subject: 'Test subject 1',
              body: 'Hello',
            )
          end.not_to raise_error
        end
        context 'and to does not match any' do
          it 'raises an appropriate error' do
            expect do
              expect_delivered_email(
                to: 'otheruser@example.com',
                subject: 'Unrelated subject',
                body: 'Hellow',
              )
            end.to raise_error(
              satisfy do |err|
                expect(err.message).to eql(
                  <<~END,
                    Unable to find email matching args:
                      to: otheruser@example.com
                      subject: Unrelated subject
                      body: Hellow
                    Sent mails:
                      - To:      [\"user@example.com\"] (did not match)
                        Subject: Test subject 1 (did not match)
                        Body:
                          - "Hellow" (not found)
                  END
                )
              end,
            )
          end
        end
      end
    end
  end

  describe '#expect_email_not_delivered' do
    context 'when searching by to' do
      context 'and not found' do
        it 'does not raise' do
          expect do
            expect_email_not_delivered(to: 'otheruser@example.com')
          end.not_to raise_error
        end
      end
      context 'and found' do
        it 'raises an appropriate error' do
          expect do
            expect_email_not_delivered(to: 'user@example.com')
          end.to raise_error(
            satisfy do |err|
              expect(err.message).to eql(
                <<~END,
                  Found an email matching the below (but shouldn't have):
                    to: user@example.com
                    subject: 
                    body: 
                  Sent mails:
                    - To:      [\"user@example.com\"]
                      Subject: Test subject 1
                END
              )
            end,
          )
        end
      end
    end

    context 'when searching by subject' do
      context 'and not found' do
        it 'does not raise' do
          expect do
            expect_email_not_delivered(subject: 'Another unrelated subject')
          end.not_to raise_error
        end
        context 'and found' do
          it 'raises an appropriate error' do
            expect do
              expect_email_not_delivered(subject: 'Test subject 1')
            end.to raise_error(
              satisfy do |err|
                expect(err.message).to eql(
                  <<~END,
                    Found an email matching the below (but shouldn't have):
                      to: 
                      subject: Test subject 1
                      body: 
                    Sent mails:
                      - To:      [\"user@example.com\"]
                        Subject: Test subject 1
                  END
                )
              end,
            )
          end
        end
      end
    end

    context 'when searching by body' do
      context 'with string' do
        context 'when not found' do
          it 'does not raise' do
            expect do
              expect_email_not_delivered(
                body: 'Hellow',
              )
            end.not_to raise_error
          end
        end
        context 'when found' do
          it 'raises an appropriate error' do
            expect do
              expect_email_not_delivered(body: 'Hello')
            end.to raise_error(
              satisfy do |err|
                expect(err.message).to eql(
                  <<~END,
                    Found an email matching the below (but shouldn't have):
                      to: 
                      subject: 
                      body: Hello
                    Sent mails:
                      - To:      [\"user@example.com\"]
                        Subject: Test subject 1
                        Body:
                          - "Hello" (found)
                  END
                )
              end,
            )
          end
        end
      end
      context 'with array' do
        context 'when not found' do
          it 'does not raise' do
            expect do
              expect_email_not_delivered(
                body: ['Hellow', 'world'],
              )
            end.not_to raise_error
          end
        end
        context 'and found' do
          it 'raises an appropriate error' do
            expect do
              expect_email_not_delivered(body: ['Hello', 'world'])
            end.to raise_error(
              satisfy do |err|
                expect(err.message).to eql(
                  <<~END,
                    Found an email matching the below (but shouldn't have):
                      to: 
                      subject: 
                      body: ["Hello", "world"]
                    Sent mails:
                      - To:      [\"user@example.com\"]
                        Subject: Test subject 1
                        Body:
                          - "Hello" (found)
                          - "world" (found)
                  END
                )
              end,
            )
          end
        end
      end
    end

    context 'when searching by to + subject + body' do
      context 'and not found' do
        it 'does not raise' do
          expect do
            expect_email_not_delivered(
              to: 'otheruser@example.com',
              subject: 'Unrelated subject',
              body: 'Hellow',
            )
          end.not_to raise_error
        end
        context 'and it matches' do
          it 'raises an appropriate error' do
            expect do
              expect_email_not_delivered(
                to: 'user@example.com',
                subject: 'Test subject 1',
                body: 'Hello',
              )
            end.to raise_error(
              satisfy do |err|
                expect(err.message).to eql(
                  <<~END,
                    Found an email matching the below (but shouldn't have):
                      to: user@example.com
                      subject: Test subject 1
                      body: Hello
                    Sent mails:
                      - To:      [\"user@example.com\"]
                        Subject: Test subject 1
                        Body:
                          - "Hello" (found)
                  END
                )
              end,
            )
          end
        end
      end
    end
  end
end
