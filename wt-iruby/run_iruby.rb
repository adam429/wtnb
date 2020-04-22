#!/usr/bin/env ruby

require 'iruby'
require 'json'

module WTCube
  class Dummy
    def session
      return Dummy.new
    end
    def send(*args)
      return "dummy"
    end
  end

  def run_file(filename)
    return if not filename

    saved = IRuby::Kernel.instance
    IRuby::Kernel.instance = Dummy.new

    nb = File.read(filename)
    json = JSON.parse(nb)
    code = (json["cells"].map do |x| x["source"] end.join("\n"))
    eval code

    IRuby::Kernel.instance = saved
  end
end

if __FILE__ == $0
  if ARGV.size!=1
    puts "usage: run_iruby [notebook]"
  else
    require_relative 'wtnb/wtnb'
    include WTCube

    filename = ARGV[0]
    filename = filename+".ipynb" if not /.ipynb$/i.match(filename)
    run_file(filename)
  end
end
