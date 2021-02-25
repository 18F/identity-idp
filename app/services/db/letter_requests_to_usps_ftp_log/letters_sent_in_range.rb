module Db
  module LetterRequestsToUspsFtpLog
    class LettersSentInRange
      def self.call(start_date, end_date)
        ::LetterRequestsToUspsFtpLog.where(ftp_at: start_date..end_date)
      end
    end
  end
end
