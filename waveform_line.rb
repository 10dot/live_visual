class Array
  def stretch( factor=1.0 )
    factor = factor.to_f
    Array.new((length*factor).ceil) do |i|
      self[(i/factor).floor]
    end
  end
end

require 'async_obj'

class WaveformLine < AsyncObject
  include Processing::Proxy

  attr_accessor :start_coords,:end_coords,:length,:steps,:inc,:line_coords,:last_updated,:thread,:repeat,:spacing,:multicolor,:color_thresholds,:line_colors,:color
  attr_reader :get_color

  def initialize(start_coords = [0, $screen_size[:height]/1.5, 0], end_coords = [$screen_size[:width], $screen_size[:height]/1.5, 0], thickness = 2, color = [255,0,0])
    @start_coords,@end_coords,@thickness,@color = start_coords, end_coords, thickness, color
    @length = calc_length
    @steps = @length/(thickness+2)
    @inc = {
      :x=>(-(@start_coords[0]-@end_coords[0]))/@steps.to_f,
      :y=>(-(@start_coords[1]-@end_coords[1]))/@steps.to_f,
      :z=>(-(@start_coords[2]-@end_coords[2]))/@steps.to_f
    }
    @ffts = []
    @repeat = 1
    @spacing = 32
    @color_thresholds = { 0=>[150,0,0], 10=>[255,0,0], 30=>[255,95,0], 60=>[255,165,0], 90=>[255,255,0], 120=>[255,255,255] }
    @line_coords = []
    @line_colors = []
    @multicolor = false
    self.update(Time.now, Time.now)
    super(1.0/$framerate)
  end

  def calc_length
    x = (@start_coords[0] - @end_coords[0]).to_f
    y = (@start_coords[1] - @end_coords[1]).to_f
    z = (@start_coords[2] - @end_coords[2]).to_f
    return Math.sqrt(x*x + y*y + z*z)
  end

  def waveform_intensity(fft = 0)
    # Sets the "intensity" of the waveform line, generally needs to be modified for line-in vs. Soundflower vs. other sources
    return fft*250
  end

  def update(last, now)
    # Asynchronously update line positions

    # Figure out how many of the global samples we need for our number of "steps"
    fft_scale = (@steps*100/$scaled_ffts.length) * 0.01
    @ffts = $scaled_ffts.stretch(fft_scale)

    # Zero relative line positions
    x = 0.0
    y = 0.0
    z = 0.0
    start_y = y

    # Draw a line from each normalized fft value to the next, and choose colors
    # TODO: replace this with drawing to a buffer that can be pulled with image() later instead of storing coords and drawing in the single-threaded draw piece
    @ffts.each_with_index do |f, i|
        intensity = waveform_intensity(f)
        if f == @ffts.last
          @line_colors[i] = get_color(intensity,0)
        else
          @line_colors[i] = get_color(intensity, waveform_intensity(@ffts[i+1]))
        end
        end_y = start_y-intensity

        @line_coords[i] = [x,y,z,x+@inc[:x],end_y,z+@inc[:z]]
        x += @inc[:x]
        start_y += @inc[:y]
        y = start_y-intensity
        z += @inc[:z]
    end

  end

  def get_color(i1,i2)
    color = @color
    @color_thresholds.each do |c|
      color = c[1] if i1 > c[0] and i2 > c[0]
    end
    return color
  end

  def render
    push_matrix
    stroke(*@color)
    stroke_weight(@thickness)
    zbias = @start_coords[2]

    # Zero to our starting coords
    translate(*@start_coords)

    # For each line repetition, draw all segments then push Z by self.spacing and repeat
    # TODO: replace this with simply rendering the buffer image with a z offset N times (rather than drawing ~640 lines X times)
    @repeat.times do
      @line_coords.each_with_index do |l,i|
        if l.length == 6
          if @multicolor then
            stroke(*@line_colors[i])
          end
          line(l[0],l[1],l[2]+zbias,l[3],l[4],l[5]+zbias)
        end
      end
      zbias-=@spacing
    end
    pop_matrix
  end

end
