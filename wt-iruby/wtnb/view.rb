
require "active_support/all"
require 'iruby'
require 'erb'
require 'nokogiri'

module WTCube

  # ----------- Assets -------------
  def include_js()
    js = [
            "https://unpkg.com/vue/dist/vue.js",
            "https://unpkg.com/chart.js@2.9.3/dist/Chart.bundle.js",
            "https://unpkg.com/vue-chartkick@0.5.1/dist/vue-chartkick.js",
            "https://unpkg.com/element-ui/lib/index.js",
         ]
     return js.map do |x| "<script src='#{x}'></script>\n" end.join()
  end

  def include_css
    css= [
            "https://unpkg.com/element-ui/lib/theme-chalk/index.css"
         ]
    css_html = css.map do |x| "<link rel='stylesheet' href='#{x}'>\n" end.join()
    return css_html
  end


  # ----------- Helper -------------
  def humanize(secs)
    ret =
    [[60, :seconds], [60, :minutes], [24, :hours], [Float::INFINITY, :days]].map{ |count, name|
      if secs > 0
        secs, n = secs.divmod(count)

        "#{n.to_i} #{name}" unless n.to_i==0
      end
    }.compact.reverse.join(' ')
    ret = "0 second" if ret==""
    return ret
  end

  def ratio(a,b)
      return 0 if b==0
      return (a.to_f / b).round(2)
  end


  def color()
    [
      "#60acfc",
      "#32d3eb",
      "#5bc49f",
      "#feb64d",
      "#ff7c7c",
      "#9287e7"
    ]
  end

  # ----------- Display -------------
  def puts_table(table,option={})
    table = table.map do |x|
      if x!=nil
        x.map do |y|
          ret = y.to_s
          if /\.(jpg|png|jpeg)$/i.match(y.to_s) then
            ret = "<img src='#{y.to_s}' width='150'/>"
          end

          ret
        end
      end
    end
    if option[:file]
      File.open(option[:file],"w") do |file|
        file.write(IRuby.table(table,maxrows:999999,maxcols:999999).object)
      end
    else
      IRuby.display IRuby.table(table,maxrows:100,maxcols:15)
      nil
    end
  end

  def puts_header(text)
    IRuby.display IRuby.html "<h1>#{text}</h1>"
  end

  def puts_image(image)
    if image.class == String then
      IRuby.display IRuby.html "<img src='#{image}' width='500'/>"
    end

    if image.class == Array then
      IRuby.display IRuby.html (image.map do |x| "<img src='#{x}' width='500'/>" end.join("\n"))
    end
    nil
  end

  def _parse_obj(obj)
    html = ""
    if obj.class==ActiveSupport::SafeBuffer
       html = obj.to_s
    elsif obj.class==String
      if /\.(jpg|png|jpeg|svg)$/.match(obj) then
        html = "<img src='#{obj}' width='500'/>"
      elsif  /^http/.match(obj) then
        html = "<iframe src='#{obj}' width='800' height='600'/>"
      elsif /<div|<a href|<img|<script/.match(obj) then
        html = obj
      else
        html = obj
      end
    else
       html = obj.ai(html:true)
    end
    return html
  end

  def puts_raw(obj)
    IRuby.display obj.to_s
  end

  def puts_display(obj)
    IRuby.display IRuby.html _parse_obj(obj)
    nil
  end

  def puts_to_file(obj,filename)
    f = open(filename,"w")
    f.write("<!DOCTYPE html>\n")
    f.write("<html>\n")
    f.write("<head>\n")
    f.write("<meta charset='utf-8'/>\n")
    f.write(include_js)
    f.write(include_css)
    f.write("</head>\n")
    f.write("<body>\n")
    f.write(_parse_obj(obj))
    f.write("</body>\n")
    f.write("</html>\n")
    f.close
  end

  def render(template,params={})
    template = File.read("template/"+template.to_s+".erb") unless template.match(/\n/)
    erb = ERB.new(template)
    html = erb.result_with_hash(params)

    # move all script to end part of html (for vue)
    doc = Nokogiri::HTML::DocumentFragment.parse(html)
    js = doc.css("script")
    js.remove
    return doc.to_html + js.reverse.to_html
  end

end
