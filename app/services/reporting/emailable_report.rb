# frozen_string_literal: true

module Reporting
  EmailableReport = Struct.new(:email_options, :table, :csv_name)
end
