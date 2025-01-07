require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/rspec/expect_offense'

require 'rails_helper'
require_relative '../../../lib/linters/mail_later_linter'

RSpec.describe RuboCop::Cop::IdentityIdp::MailLaterLinter do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  let(:config) { RuboCop::Config.new }
  let(:cop) { RuboCop::Cop::IdentityIdp::MailLaterLinter.new(config) }

  it 'registers offense when calling deliver_now method' do
    expect_offense(<<~RUBY)
      UserMailer.send_email(user).deliver_now
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/MailLaterLinter: Please send mail using deliver_now_or_later instead
    RUBY
  end

  it 'registers offense when calling deliver_later method' do
    expect_offense(<<~RUBY)
      UserMailer.send_email(user).deliver_later
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/MailLaterLinter: Please send mail using deliver_now_or_later instead
    RUBY
  end

  it 'registers offense when calling .with(...).deliver_now method' do
    expect_offense(<<~RUBY)
      UserMailer.with(user).send_email(params).deliver_now
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/MailLaterLinter: Please send mail using deliver_now_or_later instead
    RUBY
  end

  it 'registers offense when calling .with(...).deliver_now method with variable mailer' do
    expect_offense(<<~RUBY)
      mailer = UserMailer.with(user)
      mailer.send_email(params).deliver_later
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/MailLaterLinter: Please send mail using deliver_now_or_later instead
    RUBY
  end

  it 'does not register offenses for the ReportMailer' do
    expect_no_offenses(<<~RUBY)
      ReportMailer.send_email(foobar).deliver_now
    RUBY
  end
end
