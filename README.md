Live Visual
===========

Meta-programmable 3D (OpenGL) waveform visualizer written on top of ruby-processing.  This should run anywhere JRuby does (including Windows), though I haven't actually tested it on anything but OSX and Linux.

Currently, I'm borrowing bits of the AsynchronousObject class and camera placement algorithms from Preston Lee's awesome ruby-processing Starfield simulation:

https://github.com/preston/Starfield

Reqirements:
 - ruby-processing gem
 - functioning opengl (glxgears working in Linux)
 - Soundflower or similar audio redirection software to work with audio other than Line-In

Requirements for Xbox360-controlled camera:
 - the latest procontroll Java library (installed wherever your ruby-processing gem lives): http://creativecomputing.cc/p5libs/procontroll/
 - newer version of libjinput-osx.jnilib for OSX support (included in this repo to save you the time I spent making this work)
 - working Xbox360 controller driver (OSX 10.8 instructions coming soon, since this was a giant PITA)

Controls:
 - movement:  standard FPS controls on the 360 controller, L/R trigger for "barrell roll" motion
 - reset camera: A button on 360 controller


This is experimental code, and not a fully working application.  It is intented to be run inside a ruby console with 'rp5 live', and doesn't actually "do" anything unless you actively create an object and add it to the drawing stack like so:

rp5 live live_visual.rb

irb(main):001:0> l = WaveformLine.new
irb(main):002:0> $app.drawings << l

You can make the waveform line repeat into the distance in 3D space:

irb(main):002:0> l.repeat = 32
irb(main):003:0> l.spacing = 120

You can also change the color scheme:

irb(main):004:0> l.color = [0,0,255]
irb(main):005:0> l.color_thresholds = {0=>[0, 0, 150], 10=>[0, 0, 255], 30=>[0, 95, 255], 60=>[0, 165, 255], 90=>[0, 255, 255], 120=>[255, 255, 255]}

