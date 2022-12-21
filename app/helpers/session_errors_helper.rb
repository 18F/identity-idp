module SessionErrorsHelper
  def timeout(from_time)
    distance_of_time_in_words(
      from_time,
      Time.zone.now,
      except: :seconds,
    )
  end
end
