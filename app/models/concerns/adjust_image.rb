module AdjustImage
  def self.calc_resize_text(width:, height:, max_length:)
    if width > height
      resized_width = [width, max_length].min
      resized_height = ((resized_width.to_f / width.to_f) * height.to_f).to_i
      return "#{resized_width.to_i}x#{resized_height.to_i}"
    else
      resized_height = [height, max_length].min
      resized_width = ((resized_height.to_f / height.to_f) * width.to_f).to_i
      return "#{resized_width.to_i}x#{resized_height.to_i}"
    end
  end
end
