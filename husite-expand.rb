# Copyright (C) 2010 Kevin J. Fletcher
require 'haml-unfurl'
require 'fileutils'

module HuSite

  class DocumentString
    def initialize(string, default=nil)
      @string = string
      @string = default if @string == nil

      if not @string.is_a?(String)
        raise ArgumentError.new("#{self.class} expects to be passed a String. Was passed a #{string.class}!")
      end
    end
  end

  class DocumentTags < DocumentString
    def initialize(tags, default='')
      super(tags, default)

      doctags = tags.split(',')
      doctags = doctags.map {|x| x.strip() }
      doctags = doctags.uniq()
      doctags.delete('')
      @tags = doctags
    end

    def tags
      return @tags.map { |x| x.clone }
    end
  end

  class DocumentTitle < DocumentString
    def initialize(title, default='')
      super(title, default)
    end

    def title
      return @string.clone
    end
  end

  class DocumentAuthor < DocumentString
    def initialize(author, default='', raise_except=true)
      super(author, default)
    end

    def author
      return @string.clone
    end
  end

  class DocumentClass < DocumentString
    def initialize(docclass, default='', raise_except=true)
      super(docclass, default)
    end

    def class
      return @string.clone
    end
  end

  class DocumentDate < DocumentString
    def initialize(date, default='')
      super(date, default)

      begin
        @date = Date::strptime(date, "%Y-%m-%d")
      rescue ArgumentError
        if raise_except
          raise ArgumentError.new("DocumentDate did not have valid format: #{date}!")
        end

        @date = Date.new()
      end
    end

    def date
      return @date.clone
    end
  end

  class DocumentUri < DocumentString
    @@uri_fmt_title = "{title}"
    @@uri_fmt_year = "{year}"
    @@uri_fmt_month = "{month}"
    @@uri_fmt_day = "{day}"

    def initialize(uri, title, date, default="/#{@@uri_fmt_title}.html")
      super(uri, default)
      
      @uri_fmt = uri
      @uri = expand_uri(@uri_fmt, title, date)
    end

    def uri
      return @uri.clone
    end

    def expand_uri(uri_fmt, title, date)
      uri = uri_fmt
      
      if uri.include?(@@uri_fmt_title)
        if not title
          throw "No document title defined but output URI format specifies a title replacement."
        end
        
        uri = uri.gsub(@@uri_fmt_title, HuSite::uri_safe(title))
      end
      
      if uri.include?(@@uri_fmt_year) or uri.include?(@@uri_fmt_month) or uri.include?(@@uri_fmt_day)
        if not date
          throw "No document date defined but output URI format specifies a date replacement."
        end
        
        uri = uri.gsub(@@uri_fmt_year, "#{date.year}")
        uri = uri.gsub(@@uri_fmt_month, "%02d" % [date.month])
        uri = uri.gsub(@@uri_fmt_day, "%02d" % [date.day])
      end
      
      return uri
    end
  end

  class DocumentData
    def initialize(doc, docs)
      @docs = docs
      @title = DocumentTitle.new(doc.get_lowest_option('title'))
      @author = DocumentAuthor.new(doc.get_lowest_option('author'))
      @class = DocumentClass.new(doc.get_lowest_option('class'))
      @date = DocumentDate.new(doc.get_lowest_option('time'))

      tags = doc.get_all_options('tags')
      tags = tags.join(', ')
      @tags = DocumentTags.new(tags)

      ## We do this after all other data vars are set up as they may
      ## be referenced by the uri expand for the filename.
      @uri = DocumentUri.new(doc.get_lowest_option('output'), @title.title, @date.date)
    end

    def uri
      return @uri.uri
    end

    def tags
      return @tags.tags
    end

    def author
      return @author.author
    end

    def title
      return @title.title
    end

    def date
      return @date.date
    end

    def related(docclass=:ignore, include_self=false, sort=:date_dec)
      related = []
      match_scores = { }
      
      @docs.each do |doc|
        if include_self == false and self == doc
          next
        end
        
        tag_match = 0

        tags.each do |tag|
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

  class HuSiteUnfurl
    def initialize ()
      @dirs = []
      @include_dirs = []
    end
    
    def unfurl(output_dir)
      doc_data_to_doc = {}
      docs = []
      output_directory = File.expand_path(output_dir)
      file_list = get_file_list()

      file_list.each do |file|
        doc = HamlUnfurl::Unfurl.new(file, @include_dirs)
        doc_data = DocumentData.new(doc, docs)
        docs << doc_data
        doc_data_to_doc[doc_data] = doc
      end

      docs.each do |doc_data|
        data = {
          :hudata => doc_data,
        }
 
        output_file = File.join(output_dir, doc_data.uri)
        rendered = doc_data_to_doc[doc_data].render(data)
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

