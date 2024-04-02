# frozen_string_literal: true

require Rails.root.join('lib', 'aws', 'ses.rb')
ActionMailer::Base.add_delivery_method :ses, Aws::SES::Base
