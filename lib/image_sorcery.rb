require 'gm_support'
require 'color'
class ImageSorcery
  attr_reader :file

  def initialize(file)
    @file = file
  end

  # Runs ImageMagick's 'mogrify'.
  # See http://www.imagemagick.org/script/mogrify.php
  #
 def manipulate!(args={})
    tokens  = ["mogrify"]
    tokens << convert_to_arguments(args) if args
    tokens << " '#{@file}#{"[#{args[:layer].to_s}]" if args[:layer]}'"
    tokens << " -annotate #{args[:annotate].to_s}" if args[:annotate]
    tokens  = convert_to_command(tokens)
    success = run(tokens)[1]
    replace_file(args[:format].to_s.downcase, args[:layer]) if success && args[:format]
    success
  end

  # Runs ImageMagick's 'composite'.
  # See http://www.imagemagick.org/script/composite.php
  #
  def composite!(output, args={})
    tokens  = ["composite"]
    tokens << convert_to_arguments(args) if args
    tokens << " '#{@file}#{"[#{args[:layer].to_s}]" if args[:layer]}'"
    tokens << " -annotate #{args[:annotate].to_s}" if args[:annotate]
    tokens  = convert_to_command(tokens)
    success = run(tokens)[1]
    success
  end

  # Runs ImageMagick's 'convert'.
  # See http://www.imagemagick.org/script/convert.php
  #
  def convert(output, args={})
    tokens  = ["convert"]
    tokens << convert_to_arguments(args) if args
    tokens << " '#{@file}#{"[#{args[:layer].to_s}]" if args[:layer]}'"
    tokens << " -annotate #{args[:annotate].to_s}" if args[:annotate]
    tokens << " #{output}"
    tokens  = convert_to_command(tokens)
    success = run(tokens)[1]
    success
  end

  # Runs ImageMagick's 'identify'.
  # See http://www.imagemagick.org/script/identify.php
  #
  def identify(args={})
    tokens = ["identify"]
    tokens << convert_to_arguments(args) if args
    tokens << " '#{@file}#{"[#{args[:layer].to_s}]" if args[:layer]}'"
    tokens  = convert_to_command(tokens)
    output  = run(tokens)[0]
    output
  end

  # Return the x and y dimensions of an image as a hash.
  #
  def dimensions
    dimensions = identify(:layer => 0, :format => "%wx%h").chomp.split("x")
    { :x => dimensions[0].to_i,
      :y => dimensions[1].to_i }
  end

  # Returns the x dimension of an image as an integer
  #
  def width
    dimensions()[:x]
  end

  # Returns the y dimension of an image as an integer
  #
  def height
    dimensions()[:y]
  end

  # Runs ImageMagick's 'montage'.
  # See http://www.imagemagick.org/script/montage.php
  #
  def montage(sources, args={})
    tokens = ["montage"]
    tokens << convert_to_arguments(args) if args
    sources.each {|source| tokens << " '#{source}'" }
    tokens << " '#{@file}'"
    tokens  = convert_to_command(tokens)
    success = run(tokens)[1]
  end

  def filename_changed?
    (@filename_changed)
  end

  # Use convert's histogram method to determine background color of image
  # Has to be a separate function because of: complexity of arguments, output manipulation
  def background 
	tokens = ["convert"]
	tokens << " '#{@file}' "
	tokens << '-colors 16 '
	tokens << '-format "%c" histogram:info:'
	tokens = convert_to_command(tokens)
	output, success = run(tokens)

	return false if output.empty?
	# Parse histogram output for most frequent color
	result = output.split("\n").sort{|a,b| a.split(":").first.to_i <=> b.split(":").first.to_i}.last

	# Return hex representation
	hex = result.scan(/#[0-9A-F]+/).first
	return Color::RGB.by_hex(hex).html
  end

  # Get the color of the top left most pixel as minute samplespace representationi
  # of the background color of an image
  def base_color
	tokens = ["convert"]
	tokens << " '#{@file}' "
	tokens << "-format '%[fx:int(255*p{1,1}.r)],%[fx:int(255*p{1,1}.g)],%[fx:int(255*p{1,1}.b)]' "
	tokens << " info:- "
	tokens = convert_to_command(tokens)
	output, success = run(tokens)
	return false if output.empty?
	r,g,b = output.scan(/[0-9]+/).map{|y| y.to_i}
	return Color::RGB.new(r, g, b).html
  end

  private

  # Replaces the old file (with the old file format) with the newly generated one.
  # The old file will be deleted and $file will be reset.
  # If ImageMagick generated more than one file, $file will have a "*", so that all files generated
  # will be manipulated in the following steps.
  def replace_file(format, layer)
    return if  File.extname(@file) == format

    layer ||= 0
    layer = layer.split(",").first if layer.is_a? String

    File.delete @file
    @filename_changed = true

    path = File.join File.dirname(@file), File.basename(@file, File.extname(@file))
    new_file = find_file path, format, layer

    @file = new_file.call(path, format, "*") unless new_file.nil?
  end

  def find_file(path, format, layer)
    possible_paths = [
        Proc.new { |path, format, layer| "#{path}.#{format}" },
        Proc.new { |path, format, layer| "#{path}-#{layer}.#{format}" },
        Proc.new { |path, format, layer| "#{path}.#{format}.#{layer}" }
    ]

    possible_paths.find { |possible_path| File.exists?(possible_path.call(path, format, layer)) }
  end

  def convert_to_command(tokens)
    tokens[0] = prefix(tokens[0]) if respond_to? :prefix
    tokens.flatten.join("")
  end

  def convert_to_arguments(args)
    special_args = [:layer, :annotate]
    args.reject {|k, v| special_args.include?(k) }.map {|k, v| " -#{k} '#{v}'"}
  end

  def run(cmds)
    output = IO.popen(cmds.to_s) {|o| o.read }
    success = $?.exitstatus == 0 ? true : false
    [output,success]
  end
end
