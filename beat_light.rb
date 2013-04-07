require 'async_obj'

class BeatLight < AsyncObject
  include Processing::Proxy

  attr_accessor :coords, :hue, :saturation, :brightness

  def initialize(coords= [0,0,-$screen_size[:width]/2], hue = 240, saturation = 60, brightness = 50)
    @coords, @hue, @saturation, @brightness = coords, hue, saturation, brightness

    @flare = load_image("flare.png")

    self.update(Time.now, Time.now)
    super(1.0/$framerate)
  end

  def update(last, now)
    if $beat.is_onset
      @brightness = 100
    end
  end

  def render
    color_mode(HSB, 360, 100, 100)
    point_light(@hue, @saturation, @brightness, @coords[0], @coords[1], @coords[2])
    color_mode(RGB)
  end

end
