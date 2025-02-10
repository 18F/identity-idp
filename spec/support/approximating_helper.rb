module ApproximatingHelper
  def range_approximating(size, vary_left: nil, vary_right: nil)
    left_size = size
    left_size += vary_left unless vary_left.nil?
    right_size = size
    right_size += vary_right unless vary_right.nil?

    left_size..right_size
  end
end
