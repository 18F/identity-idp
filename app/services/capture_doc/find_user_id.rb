module CaptureDoc
  class FindUserId
    def self.call(request_token)
      dc = DocCapture.find_by(request_token: request_token)
      return if dc.nil? || dc.expired?
      dc.user_id
    end
  end
end
