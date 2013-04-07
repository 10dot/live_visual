require 'async_obj'

class BeatLight < AsyncObject
  include Processing::Proxy

  attr_accessor :coords, :hue, :saturation, :brightness, :radius, :base_pulse_count

  def initialize(coords= [0,0,-$screen_size[:width]/2], hue = 240, saturation = 60, brightness = 50)
    @coords, @hue, @saturation, @brightness = coords, hue, saturation, brightness

    @beat = false
    @pulse_count = $framerate/10
    @base_pulse_count = $framerate/10
    @radius_factor=0.0

    @radius = 30

    self.update(Time.now, Time.now)
    super(1.0/$framerate)
  end

  def update(last, now)
    if $beat.is_onset
      @beat = true
      @pulse_count = @base_pulse_count
    else
      if @beat
        if @pulse_count > 0
          @radius_factor+=0.2
          @pulse_count-=1
        else
          @beat = false
          @pulse_count = @base_pulse_count
        end
      else
        if @radius_factor > 1.0
          @radius_factor-=0.2
        end
      end
    end
  end

  def render
    translate(*@coords)
    r = @radius*@radius_factor
    sphere(r)
  end

end
