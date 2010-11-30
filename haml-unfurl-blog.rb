# Copyright (C) 2010 Kevin J. Fletcher
require 'haml-unfurl'
require 'fileutils'

module HamlUnfurl
  class BlogUnfurlData
    attr_accessor :doc, :title, :author, :datetime, :tags, :output_file

    def initialize()
      @doc = nil
      @title = nil
      @author = nil
      @datetime = nil
      @tags = nil
      @output_file = nil
    end
  end

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
        doc_data = BlogUnfurlData.new()
        doc_data.doc = Unfurl.new(file, @include_dirs)
        
        doc_data.title = doc_data.doc.get_lowest_option('title')
        doc_data.title = 'No Title Set' if doc_data.title == nil

        doc_data.author = doc_data.doc.get_lowest_option('author')
        doc_data.author = 'No Author Set' if doc_data.author == nil

        doc_data.datetime = doc_data.doc.get_lowest_option('time')
        doc_data.datetime = getopt_datetime(doc_data.datetime) if doc_data.datetime != nil
        doc_data.datetime = DateTime.new() if doc_data.datetime == nil

        doc_data.tags = doc_data.doc.get_all_options('tags')
        doc_data.tags = doc_data.tags.join(', ')
        doc_data.tags = doc_data.tags.split(',')
        doc_data.tags = doc_data.tags.map {|x| x.strip() }
        doc_data.tags.uniq!()
        doc_data.tags.delete('')

        ## We do this after all other data vars are set up as they may
        ## be referenced by the uri expand for the filename.
        doc_data.output_file = doc_data.doc.get_lowest_option('output')
        doc_data.output_file = "#{@@uri_fmt_title}.html" if doc_data.output_file == nil
        doc_data.output_file = get_output_file(output_dir, doc_data.output_file, doc_data)
        
        docs << doc_data
      end

      docs.each do |doc_data|
        data = {
          :title => doc_data.title,
          :author => doc_data.author,
          :datetime => doc_data.datetime,
          :tags => doc_data.tags
        }
          
        rendered = doc_data.doc.render(data)
        output_file_dir = File.dirname(doc_data.output_file)
        FileUtils.mkdir_p(output_file_dir)
        File.open(doc_data.output_file, 'w') { |f| f.write(rendered) }
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

    def getopt_datetime(datetime)
      time_key = 'time'

      begin
        return Date::strptime(datetime, "%Y-%m-%d %H:%M")
      rescue ArgumentError
        
      end

      return nil
    end

    def get_output_file(output_dir, uri_fmt, doc)
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
      nonsafe = nonsafe.gsub(/[^a-zA-Z0-9_]/, '_')
      nonsafe = nonsafe.gsub(/_{2,}/, '_')
      nonsafe = nonsafe.gsub(/^_|_$/, '')
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

