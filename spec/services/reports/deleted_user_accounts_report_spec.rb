require 'rails_helper'

describe Reports::DeletedUserAccountsReport do
  let(:issuer) { 'urn:gov:gsa:openidconnect:sp:sinatra' }
  let(:email) { 'foo@bar.com' }
  let(:name) { 'An SP' }
  let(:user) { create(:user) }
  let(:last_authenticated_at) { '2020-01-02 12:03:04' }
  let(:uuid) { 'foo' }

  subject { described_class.new }

  it 'is does not send out an email with nothing configured' do
    expect(UserMailer).to_not receive(:deleted_user_accounts_report)

    subject.call
  end

  it 'sends out a report to the email listed with one deleted user account' do
    create(:identity, service_provider: issuer,
                      user: user,
                      uuid: uuid,
                      last_authenticated_at: last_authenticated_at + ' UTC')
    user.destroy!

    allow(Figaro.env).to receive(:deleted_user_accounts_report_configs).and_return(
      [{ 'name' => name, 'issuers' => [issuer], 'emails' => [email] }].to_json,
    )
    allow(UserMailer).to receive(:deleted_user_accounts_report).and_call_original

    report = "#{last_authenticated_at}, #{uuid}\r\n"
    expect(UserMailer).to receive(:deleted_user_accounts_report).with(
      email: email, name: name, issuers: [issuer], data: report,
    )

    subject.call
  end
end
