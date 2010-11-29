require 'date'
require 'haml'

module HamlUnfurl
  class LookupString
    attr_accessor :string

    def initialize(string)
      @string = string
    end
  end

  class Unfurl
    attr_accessor :include_dirs

    def initialize(filename)
      @file_content = File.read(filename)
      @raw_options = get_options(@file_content)
      @template, @template_lookup = getopt_template()
      @tags = getopt_tags()
      @author = getopt_general('author')
      @title = getopt_general('title')
      @datetime = getopt_time()
      @include_dirs = ['.']
    end

    def getopt_template()
      template_key = 'template'
      opt_regex_template = /(\w+)\s*\((\w+)\)/

      if @raw_options.key?(template_key)
        if opt_regex_template =~ @raw_options[template_key]
          return "#$1".to_sym(), "#$2".to_sym()
        end
      end
      return nil, nil
    end
    
    def getopt_time()
      time_key = 'time'

      if @raw_options.key?(time_key)
        begin
          return Date::strptime(@raw_options[time_key], "%Y-%m-%d %H:%M")
        rescue ArgumentError

        end
      end

      return nil
    end

    def getopt_tags()
      tags_key = 'tags'

      if @raw_options.key?(tags_key)
        tags = @raw_options[tags_key].split(',')
        tags = tags.map {|x| x.strip() }
        tags.delete('')
        return tags
      end

      return nil
    end

    def getopt_general(key)
      if @raw_options.key?(key)
        return @raw_options[key]
      end

      return nil
    end

    def get_options(content)
      options = {}
      opt_regex = /^-\#\s*([a-zA-Z0-9-]+)\s*:(.*)$/

      content.scan(opt_regex).each do |match|
        options[match[0]] = match[1].strip()
      end

      return options
    end

    def render(data={}, lookups={})
      lookup_backup = nil
      render_data={}
      
      data.each do |x,y|
        render_data[x] = y
      end

      if @title 
        render_data[:title] = @title 
      end
      if @author 
        render_data[:author] = @author 
      end
      if @datetime
        render_data[:datetime] = @datetime
      end
      if @tags
        render_data[:tags] = @tags
      end

      output = render_buffer(@file_content, render_data, lookups)

      if @template and @template_lookup
        if lookups.key?(@template_lookup)
          lookup_backup = lookups[@template_lookup]
        end

        lookups[@template_lookup] = LookupString.new(output)
        template = Unfurl.new(locate_file(@template))
        template.include_dirs = @include_dirs
        output = template.render(render_data, lookups)
        
        if lookup_backup != nil
          lookups[@template_lookup] = lookup_backup
        end
      end

      return output
    end

    def render_buffer(buffer, data, lookups)
      engine = Haml::Engine.new(buffer)
      scope = Object.new

      output = engine.render(scope, data) do |lookup|
        scope.instance_variable_get('@haml_buffer').buffer << render_lookup(lookup, lookups, data)
      end

      return output
    end

    def render_lookup(lookup, lookups, data)
      filename = nil

      if lookups.key?(lookup)
        value = lookups[lookup]
      
        if value.is_a?(LookupString)
          return value.string
        else
          filename = locate_file(value)
        end
      else
        filename = locate_file(lookup)
      end

      if filename and File.exist?(filename)
        return render_buffer(File.read(filename), data, lookups)
      end
      
      throw "Can't Find File"
    end

    def locate_file(filename)
      if filename.is_a?(Symbol):
          filename = "#{filename}"
      end

      if not filename =~ /\.haml$/
        filename = "#{filename}.haml"
      end

      @include_dirs.each do |path|
        test_path = File.join(path, filename)

        if File.exists?(test_path)
          return test_path
        end
      end

      throw "Can't Find File"
    end
  end

  myUnfurl = Unfurl.new('test-document.haml')
  myUnfurl.include_dirs << './templates/'
  output = myUnfurl.render()
  puts output
  File.open('test.html', 'w') {|f| f.write(output)}
end

