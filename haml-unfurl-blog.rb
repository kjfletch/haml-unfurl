require 'haml-unfurl'
require 'fileutils'

module HamlUnfurl
  class BlogUnfurl
    @@uri_fmt_title = "{title}"
    @@uri_fmt_year = "{year}"
    @@uri_fmt_month = "{month}"
    @@uri_fmt_day = "{day}"

    def initialize ()
      @dirs = []
      @include_dirs = []
    end
    
    def unfurl(output_dir)
      docs = []
      output_directory = File.expand_path(output_dir)
      file_list = get_file_list()

      file_list.each do |file|
        docs << Unfurl.new(file, @include_dirs)
      end

      docs.each do |doc|
        rendered = doc.render()
        output_file = get_output_file(output_dir, doc)
        output_file_dir = File.dirname(output_file)
        FileUtils.mkdir_p(output_file_dir)
        File.open(output_file, 'w') { |f| f.write(rendered) }
      end
    end

    def add_dir(directory, recursive=false)
      if recursive == true
        throw "Not implemented."
      end

      if File.directory?(directory)
        @dirs << File.expand_path(directory)
        @dirs.uniq!()
      end
    end

    def add_include(directory)
      if File.directory?(directory)
        @include_dirs << File.expand_path(directory)
        @include_dirs.uniq!()
      end
    end

    def get_output_file(output_dir, doc)
      uri_fmt = '#{@@uri_fmt_title}.html'

      if doc.uri_fmt
        uri_fmt = doc.uri_fmt
      end

      if uri_fmt.include?(@@uri_fmt_title)
        if not doc.title
          throw "No document title defined but output URI format specifies a title replacement."
        end

        uri_fmt.gsub!(@@uri_fmt_title, uri_safe(doc.title))
      end

      if uri_fmt.include?(@@uri_fmt_year) or uri_fmt.include?(@@uri_fmt_month) or uri_fmt?(@@uri_fmt_day)
        if not doc.datetime
          throw "No document datetime defined but output URI format specifies a datetime replacement."
        end

        uri_fmt.gsub!(@@uri_fmt_year, "#{doc.datetime.year}")
        uri_fmt.gsub!(@@uri_fmt_month, "#{doc.datetime.month}")
        uri_fmt.gsub!(@@uri_fmt_day, "#{doc.datetime.day}")
      end
      
      return File.join(output_dir, uri_fmt)
    end

    def uri_safe(nonsafe)
      nonsafe.gsub!(/[^a-zA-Z0-9_]/, '_')
      nonsafe.gsub!(/_{2,}/, '_')
      nonsafe.gsub!(/^_|_$/, '')
      return nonsafe
    end

    def get_file_list()
      file_list = []
      
      @dirs.each do |dir|
        if File.directory?(dir)
          Dir.new(dir).entries.each do |file|
            if /\.haml$/ =~ file
              file_list << File.join(dir, file)
            end
          end
        end
      end

      return file_list
    end
  end

  blog_unfurl = BlogUnfurl.new()
  blog_unfurl.add_include('templates')
  blog_unfurl.add_dir('blog')
  blog_unfurl.add_dir('projects')
  blog_unfurl.unfurl('./output')
end

