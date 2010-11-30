# Copyright (C) 2010 Kevin J. Fletcher
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
    attr_reader :options

    def initialize(filename, include_dirs=[])
      @include_dirs = include_dirs.concat([]).uniq()
      @file_content = File.read(filename)
      @options = get_options(@file_content)
      @template, @template_lookup = getopt_template()
    end

    def get_lowest_option(option_name)
      options = get_all_options(option_name)

      if options.length > 0
        return options[-1]
      end
      
      return nil
    end

    def get_highest_option(option_name)
      options = get_all_options(option_name)

      if options.length > 0
        return options[0]
      end
        
      return nil
    end

    def get_all_options(option_name)
      opts = []
      opt = getopt_general(option_name)
      
      if opt
        opts << opt
      end

      if @template
        opts = opts.concat(@template.get_all_options(option_name))
      end

      return opts
    end

    def getopt_template()
      template_key = 'template'
      opt_regex_template = /(\w+)\s*\((\w+)\)/

      if @options.key?(template_key)
        if opt_regex_template =~ @options[template_key]
          template, symbol =  "#$1".to_sym(), "#$2".to_sym()
          template = Unfurl.new(locate_file(template), @include_dirs)
          return template, symbol
        end
      end
      return nil, nil
    end

    def getopt_general(key)
      if @options.key?(key)
        return @options[key]
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

      output = render_buffer(@file_content, render_data, lookups)

      if @template and @template_lookup
        if lookups.key?(@template_lookup)
          lookup_backup = lookups[@template_lookup]
        end

        lookups[@template_lookup] = LookupString.new(output)
        output = @template.render(render_data, lookups)
        
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
end

