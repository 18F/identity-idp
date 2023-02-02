module ApproximatingHelper
  def range_approximating(size, vary_left: nil, vary_right: nil)
    left_size = size
    left_size += size if vary_left
    right_size = size
    right_size += size if vary_right

    left_size..right_size
  end
end
