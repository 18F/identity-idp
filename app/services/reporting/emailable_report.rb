module Reporting
  EmailableReport = Struct.new(:email_options, :table, :csv_name)
end
