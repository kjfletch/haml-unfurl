require 'haml'

module HamlUnfurl
  class LookupString
    attr_accessor :string

    def initialize(string)
      @string = string
    end
  end

  class Unfurl
    def initialize(filename)
      @file_content = File.read(filename)
      @template, @template_lookup = getopt_template()
    end

    def getopt_template()
      opt_regex_template = /^-\#\s*template:\s+(\w+)\s*\((\w+)\)/

      if opt_regex_template =~ @file_content
        return "#$1".to_sym(), "#$2".to_sym()
      end

      return nil, nil
    end

    def render(data={}, lookups={})
      lookup_backup = nil
      output = render_buffer(@file_content, data, lookups)

      if @template and @template_lookup
        if lookups.key?(@template_lookup)
          lookup_backup = lookups[@template_lookup]
        end

        lookups[@template_lookup] = LookupString.new(output)
        template = Unfurl.new(locate_file(@template))
        output = template.render(data, lookups)
        
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

      # TODO: need to add stuff here to locate file from a list of
      # include paths.
      
      return filename
    end

  end

  myUnfurl = Unfurl.new('test-document.haml')
  output = myUnfurl.render()
  puts output
  File.open('test.html', 'w') {|f| f.write(output)}
end

