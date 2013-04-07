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
      $framerate = 30
      $screen_size = { :width=>1280, :height=>720 }

      size($screen_size[:width],$screen_size[:height], OPENGL)
      if frame != nil
        frame.set_resizable(true);
      end
      hint ENABLE_OPENGL_4X_SMOOTH
      frame_rate($framerate)

      @drawings = []
      @camera_coords = [$screen_size[:width]/2.0, $screen_size[:height]/2.0, $screen_size[:height]/2.0, $screen_size[:width]/2.0, $screen_size[:height]/2.0, 0.0, 0.0, 1.0, 0.0]

      @controll =ControllIO.get_instance(self)

      @joypad = nil

      for i in 0...@controll.get_number_of_devices
        if @controll.get_device(i).get_name == 'Controller'
          @joypad = @controll.get_device(i)
        end
      end

      unless @joypad.nil?
        @joypad.set_tolerance(0.09)
        @left_stick = @joypad.get_stick(0)
        @right_stick = @joypad.get_stick(1)
        @triggers = @joypad.get_stick(2)
      end

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
    update_sound

    prerender_insert

    configure_gl
    background(0)
    lights

    unless @joypad.nil?
      get_joypad_inputs
    end
    move_camera_for_frame

    @drawings.each do |d|
      push_matrix
      d.render
      pop_matrix
    end

    postrender_insert
  end

  def get_joypad_inputs
    for i in 0..14
      puts "#{i} pressed" if @joypad.get_button(i).pressed
    end

    reset_camera if @joypad.get_button(11).pressed

    @camera_move_z = @left_stick.get_x
    @camera_move_x = @left_stick.get_y
    @camera_rotate_y = -@right_stick.get_y
    @camera_rotate_z = @triggers.get_x+-@triggers.get_y
    #inverted
    @camera_rotate_x = @right_stick.get_x
  end

  def move_camera_for_frame
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

  def set_camera
    @camera_coords[0] = mouse_x
    @camera_coords[1] = mouse_y
    camera(*@camera_coords)
  end

  def prerender_insert
    return
  end

  def postrender_insert
    return
  end

  def setup_screen
    background(0)
  end

  def setup_sound
    # Creates a Minim object
    @minim = Minim.new(self)
    # Lets Minim grab sound data from mic/soundflower

    @input = @minim.get_line_in

    # Gets FFT values from sound data
    @fft = FFT.new(@input.mix.size, 44100)
    # Our beat detector object
    $beat = BeatDetect.new

    #grab a number of freqs, currently 4% of them (640 of 15970)
    @freqs = (30...16000).to_a.stretch(0.04)

    # Create arrays to store the current FFT values,

    #   previous FFT values, highest FFT values we've seen,
    #   and scaled/normalized FFT values (which are easier to work with)
    $current_ffts   = Array.new(@freqs.size, 0.001)
    $previous_ffts  = Array.new(@freqs.size, 0.001)
    $max_ffts       = Array.new(@freqs.size, 0.001)
    $scaled_ffts    = Array.new(@freqs.size, 0.001)

    # We'll use this value to adjust the "smoothness" factor

    #   of our sound responsiveness
    @fft_smoothing = 0.8
  end

  def update_sound
    @fft.forward(@input.mix)

    $previous_ffts = $current_ffts

    # Iterate over the frequencies of interest and get FFT values
    @freqs.each_with_index do |freq, i|
      # The FFT value for this frequency
      new_fft = @fft.get_freq(freq)

      # Set it as the frequncy max if it's larger than the previous max

      $max_ffts[i] = new_fft if new_fft > $max_ffts[i] unless new_fft > 80

      # Use our "smoothness" factor and the previous FFT to set a current FFT value
      $current_ffts[i] = ((1 - @fft_smoothing) * new_fft) + (@fft_smoothing * $previous_ffts[i])
      #@current_ffts[i] = new_fft

      # Set a scaled/normalized FFT value that will be

      #   easier to work with for this frequency
      $scaled_ffts[i] = ($current_ffts[i]/$max_ffts[i])
    end

    # Check if there's a beat, will be stored in @beat.is_onset
    $beat.detect(@input.mix)
  end
end
