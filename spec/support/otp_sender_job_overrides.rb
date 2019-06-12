SmsOtpSenderJob.class_eval do
  def self.perform_later(*args)
    perform_now(*args)
  end
end
VoiceOtpSenderJob.class_eval do
  def self.perform_later(*args)
    perform_now(*args)
  end
end
