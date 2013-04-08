require 'async_obj'

# Everything about this sucks, it is only me fucking around and shouldn't be considered "real" code

class BeatLight < AsyncObject
  include Processing::Proxy

  attr_accessor :coords, :color, :radius,:specular,:radius_adjustment,:animation_frames

  def initialize(coords= [0,0,-$screen_size[:width]/2], color = [0,0,255,155], radius = 50)
    @coords, @color, @radius = coords, color, radius

    @beat = false
    @frame_count = 0
    @animation_frames = 3
    @radius_factor=1.0
    @radius_adjustment=0.3
    @shininess = 1.0

    self.update(Time.now, Time.now)
    super(1.0/$framerate)
  end

  def update(last, now)
    @beat = true if $beat.is_onset

    if @beat
      if @frame_count >= @animation_frames
        if @radius_factor <= 1.0
          @radius_factor = 1.0
          @beat = false
          @frame_count = 0
          return
        else
          @radius_factor-=@radius_adjustment
        end
      else
        @radius_factor+=@radius_adjustment
      end
      @frame_count+=1
    end
  end

  def render
    no_stroke
    translate(*@coords)
    fill(*@color)
    point_light(255,255,255,-(@radius+10),-(@radius+10),0)
    point_light(255,255,255,+(@radius+10),+(@radius+10),0)
    r = @radius*@radius_factor
    shininess(@shininess)
    sphere(r)
  end

end
