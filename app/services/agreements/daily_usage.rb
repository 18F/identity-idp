module Agreements
  class DailyUsage
    attr_reader :ial1_requests, :ial2_requests, :ial1_responses, :ial2_responses, :unique_users

    def initialize(date)
      @date = date
      @ial1_requests = 0
      @ial2_requests = 0
      @ial1_responses = 0
      @ial2_responses = 0
      @unique_users = Set.new
    end

    def update(return_log)
      if requested_today?(return_log) || responded_today?(return_log)
        case return_log.ial
        when 1
          @ial1_requests += 1 if requested_today?(return_log)
          if responded_today?(return_log)
            @ial1_responses += 1
            @unique_users.add(return_log.user_id)
          end
        when 2
          @ial2_requests += 1 if requested_today?(return_log)
          if responded_today?(return_log)
            @ial2_responses += 1
            @unique_users.add(return_log.user_id)
          end
        end
      end

      self
    end

    private

    attr_writer :ial1_requests, :ial2_requests, :ial1_responses, :ial2_responses, :unique_users
    attr_reader :date

    def requested_today?(return_log)
      return_log.requested_at.to_date == date
    end

    def responded_today?(return_log)
      return_log.returned_at.to_date == date
    end
  end
end
