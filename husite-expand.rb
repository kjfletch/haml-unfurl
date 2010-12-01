# Copyright (C) 2010 Kevin J. Fletcher
require 'haml-unfurl'
require 'fileutils'

module HuSite

  class HuSitePublic
    attr_reader :title, :author, :tags, :datetime, :uri

    def initialize(doc_data, docs)
      @doc_data = doc_data
      @docs = docs
      @title = @doc_data.title
      @author = @doc_data.author
      @datetime = @doc_data.datetime
      @uri = @doc_data.uri
      @tags = @doc_data.tags
    end

    def related(docclass=:ignore, include_self=false, sort=:date_dec)
      related = []
      match_scores = { }
      
      @docs.each do |doc|
        if include_self == false and doc == @doc_data.doc
          next
        end
        
        tag_match = 0

        @tags.each do |tag|
          if doc.tags.include?(tag)
            tag_match += 1
          end
        end

        if tag_match > 0
          related << doc
          match_scores[doc] = tag_match
        end
      end

      return related
    end
  end

  class HuSiteData
    attr_accessor :doc, :title, :author, :datetime, :class, :tags, :uri

    @@uri_fmt_title = "{title}"
    @@uri_fmt_year = "{year}"
    @@uri_fmt_month = "{month}"
    @@uri_fmt_day = "{day}"

    def initialize(doc)
      @doc = doc

      @title = @doc.get_lowest_option('title')
      @title = 'No Title Set' if @title == nil

      @author = @doc.get_lowest_option('author')
      @author = 'No Author Set' if @author == nil

      @class = @doc.get_lowest_option('class')
      @class = '' if @class == nil

      @datetime = @doc.get_lowest_option('time')
      @datetime = getopt_datetime(@datetime) if @datetime != nil
      @datetime = DateTime.new() if @datetime == nil

      @tags = @doc.get_all_options('tags')
      @tags = @tags.join(', ')
      @tags = @tags.split(',')
      @tags = @tags.map {|x| x.strip() }
      @tags.uniq!()
      @tags.delete('')

      ## We do this after all other data vars are set up as they may
      ## be referenced by the uri expand for the filename.
      @uri = @doc.get_lowest_option('output')
      @uri = "#{@@uri_fmt_title}.html" if @uri == nil
      @uri = get_output_file(@uri)
    end

    def get_output_file(uri_fmt)
      uri = uri_fmt

      if uri.include?(@@uri_fmt_title)
        if not @title
          throw "No document title defined but output URI format specifies a title replacement."
        end

        uri.gsub!(@@uri_fmt_title, HuSite::uri_safe(@title))
      end

      if uri.include?(@@uri_fmt_year) or uri.include?(@@uri_fmt_month) or uri?(@@uri_fmt_day)
        if not @datetime
          throw "No document datetime defined but output URI format specifies a datetime replacement."
        end

        uri.gsub!(@@uri_fmt_year, "#{@datetime.year}")
        uri.gsub!(@@uri_fmt_month, "%02d" % [@datetime.month])
        uri.gsub!(@@uri_fmt_day, "%02d" % [@datetime.day])
      end
      
      return uri
    end

    def getopt_datetime(datetime)
      time_key = 'time'

      begin
        return DateTime::strptime(datetime, "%Y-%m-%d %H:%M")
      rescue ArgumentError
        
      end

      return nil
    end

  end

  class HuSiteUnfurl
    def initialize ()
      @dirs = []
      @include_dirs = []
    end
    
    def unfurl(output_dir)
      docs = []
      output_directory = File.expand_path(output_dir)
      file_list = get_file_list()

      file_list.each do |file|
        doc = HamlUnfurl::Unfurl.new(file, @include_dirs)
        doc_data = HuSiteData.new(doc)
        docs << doc_data
      end

      docs.each do |doc_data|
        hupublic = HuSitePublic.new(doc_data, docs)

        data = {
          :hudata => hupublic,
        }
 
        output_file = File.join(output_dir, doc_data.uri)
        rendered = doc_data.doc.render(data)
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

  def self.uri_safe(nonsafe)
    nonsafe = nonsafe.gsub(/[^a-zA-Z0-9_]/, '_')
    nonsafe = nonsafe.gsub(/_{2,}/, '_')
    nonsafe = nonsafe.gsub(/^_|_$/, '')
    return nonsafe
  end
end

