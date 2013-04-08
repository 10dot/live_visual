require 'waveform_line'
require 'beat_light'

class LiveVisual < Processing::App
  load_library "opengl"
  load_library "minim"
  load_library 'procontroll'
  import 'procontroll'
  import "ddf.minim"
  import "ddf.minim.analysis"
  import "processing.opengl"
  import "javax.media.opengl"


  CAMERA_SPEED = 10 # Pixels per wall second.
  CAMERA_ROTATE_SPEED = 0.03 # Radians per wall second.

  attr_accessor :drawings, :camera_coords, :joypad, :stick1, :stick2, :controll
  attr_reader :reset_camera

  def setup
      # TODO: make framerate 60 by having objects render to individual frame buffers, then draw images (instead of primitives) each frame
      $framerate = 30
      $screen_size = { :width=>1280, :height=>720 }

      # Make the window resizeable.  TODO: figure out fullscreen/multimonitor
      size($screen_size[:width],$screen_size[:height], OPENGL)
      if frame != nil
        frame.set_resizable(true);
      end

      # This seems to enable anti-aliasing, I think
      hint ENABLE_OPENGL_4X_SMOOTH
      frame_rate($framerate)

      # Set a baseline for camera_coords to use later with the camera reset button.
      @drawings = []
      @camera_coords = [$screen_size[:width]/2.0, $screen_size[:height]/2.0, $screen_size[:height]/2.0, $screen_size[:width]/2.0, $screen_size[:height]/2.0, 0.0, 0.0, 1.0, 0.0]

      # Create a procontroll object and look for a device named 'Controller' (Xbox360 wired controller)
      @controll =ControllIO.get_instance(self)
      @joypad = nil

      for i in 0...@controll.get_number_of_devices
        if @controll.get_device(i).get_name == 'Controller'
          @joypad = @controll.get_device(i)
        end
      end

      # We found a joypad, so set up the sticks
      unless @joypad.nil?
        @joypad.set_tolerance(0.09)
        @left_stick = @joypad.get_stick(0)
        @right_stick = @joypad.get_stick(1)
        @triggers = @joypad.get_stick(2)
      end

      # Initial relative camera positions, modified with gl transform matrices to move the camera
      @x = 0.0
      @y = 0.0
      @z = 0.0
      @rz = 0.0

      setup_sound
      setup_screen
      reset_camera
  end

  def configure_gl
    pgl = g
    gl = pgl.gl
    pgl.beginGL
    gl.gl_enable(GL::GL_BLEND)
    gl.gl_blend_func(GL::GL_SRC_ALPHA, GL::GL_ONE)
    pgl.endGL
  end

  def draw
    # Update our frequency samples
    update_sound

    # Insert for live-coding
    prerender_insert

    # Blank the screen and set up lights for next frame
    configure_gl
    background(0)
    lights

    # Poll joypad inputs since procontroll can't issue callbacks to Ruby
    unless @joypad.nil?
      get_joypad_inputs
    end

    # Move the camera, if applicable
    move_camera_for_frame

    # Iterate through the drawings stack and render each one.  Due to limitations with Processing/JRuby, this seems to be limited to a single thread
    @drawings.each do |d|
      push_matrix
      d.render
      pop_matrix
    end

    # Another live-coding insertion point
    postrender_insert
  end

  def get_joypad_inputs
    # For debug purposes to map controller buttons
    for i in 0..14
      puts "#{i} pressed" if @joypad.get_button(i).pressed
    end

    reset_camera if @joypad.get_button(11).pressed

    # Move the camera if applicable
    @camera_move_z = @left_stick.get_x
    @camera_move_x = @left_stick.get_y
    @camera_rotate_y = -@right_stick.get_y

    # Triggers can be accessed several ways with procontroll, this seems to be the most reliable
    @camera_rotate_z = @triggers.get_x+-@triggers.get_y
    @camera_rotate_x = @right_stick.get_x
  end

  def move_camera_for_frame
    # Largely borrowed from Preson Lee's Starfield simulator
    begin_camera
    @dx = (@camera_move_x || 0.0) * CAMERA_SPEED
    @dy = (@camera_move_y || 0.0) * CAMERA_SPEED
    @dz = (@camera_move_z || 0.0) * CAMERA_SPEED
    @drx = (@camera_rotate_x || 0.0) * CAMERA_ROTATE_SPEED
    @dry = (@camera_rotate_y || 0.0) * CAMERA_ROTATE_SPEED
    @drz = (@camera_rotate_z || 0.0) * CAMERA_ROTATE_SPEED
    @x += @dx
    @y += @dy
    @z += @dz
    @rz += @drz

    # This is SO MUCH EASIER than the manual way:
    translate(@dx, 0.0, 0.0) if !@camera_move_x.nil? && @camera_move_x != 0.0
    translate(0.0, @dy, 0.0) if !@camera_move_y.nil? && @camera_move_y != 0.0
    translate(0.0, 0.0, @dz) if !@camera_move_z.nil? && @camera_move_z != 0.0
    rotate_x(@drx) if !@camera_rotate_x.nil? && @camera_rotate_x != 0.0
    rotate_y(@dry) if !@camera_rotate_y.nil? && @camera_rotate_y != 0
    rotate_z(@drz) if !@camera_rotate_z.nil? && @camera_rotate_z != 0.0
    end_camera
  end

  def reset_camera
    camera(*@camera_coords)
  end

  def prerender_insert
    return
  end

  def postrender_insert
    return
  end

  def setup_screen
    # Add stuff here for initial screen setup
    background(0)
  end

  def setup_sound
    @minim = Minim.new(self)
    @input = @minim.get_line_in

    @fft = FFT.new(@input.mix.size, 44100)
    $beat = BeatDetect.new

    # Use new Array.stretch to get subset of frequencies, currently 4%
    @freqs = (30...16000).to_a.stretch(0.04)


    # Set up global fft arrays to use later
    $current_ffts   = Array.new(@freqs.size, 0.001)
    $previous_ffts  = Array.new(@freqs.size, 0.001)
    $max_ffts       = Array.new(@freqs.size, 0.001)
    $scaled_ffts    = Array.new(@freqs.size, 0.001)

    # Concept borrowed from other minim-based processing apps to smooth out fft response
    @fft_smoothing = 0.8
  end

  def update_sound
    @fft.forward(@input.mix)

    $previous_ffts = $current_ffts

    @freqs.each_with_index do |freq, i|
      new_fft = @fft.get_freq(freq)

      # Set a new frequency max, but filter > 80 to avoid "poisoning" the normalized values with one really loud sound
      $max_ffts[i] = new_fft if new_fft > $max_ffts[i] unless new_fft > 80

      # This smoothing algorithm is kinda janky
      $current_ffts[i] = ((1 - @fft_smoothing) * new_fft) + (@fft_smoothing * $previous_ffts[i])

      # Borrowed fft scaling idea, works mostly
      $scaled_ffts[i] = ($current_ffts[i]/$max_ffts[i])
    end

    # Detect the beat, and do it in stereo
    $beat.detect(@input.mix)
  end
end
