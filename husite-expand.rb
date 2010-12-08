# Copyright (C) 2010 Kevin J. Fletcher
require 'haml-unfurl'
require 'fileutils'
require 'uri'

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

    def docclass
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
    def initialize(uri, title, date, default='/{title}.html')
      super(uri, default)
      @uri_fmt = uri
      expand_data = {}
      expand_data['title'] = title if title
      if date
        expand_data['year'] = "#{date.year}"
        expand_data['month'] = "%02d" % [date.month]
        expand_data['day'] = "%02d" % [date.day]
      end
      @uri = HuSite::expand_option(@uri_fmt, {}, expand_data)
    end

    def uri
      return @uri.clone
    end
  end

  class DocumentData
    def initialize(doc, docs)
      @docs = docs
      @title = DocumentTitle.new(doc.get_lowest_option('title'))
      @author = DocumentAuthor.new(doc.get_lowest_option('author'))
      @docclass = DocumentClass.new(doc.get_lowest_option('class'))
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

    def docclass
      return @docclass.docclass
    end

    def date
      return @date.date
    end
    
    def related(docclass=:ignore, sort=:date_desc)
      related = []
      match_scores = { }
      
      docclass = @docclass if docclass == :self

      @docs.each do |doc|
        tag_match = 0

        tags.each do |tag|
          if doc.tags.include?(tag)
            tag_match += 1
          end
        end

        next if docclass != :ignore and docclass != @docclass

        if tag_match > 0
          related << doc
          match_scores[doc] = tag_match
        end
      end

      related = related - [self]
      related.sort! {|x,y| x.date <=> y.date } if sort == :date_desc
      related.sort! {|x,y| y.date <=> x.date } if sort == :date_asc
      related.sort! {|x,y| match_scores[x] <=> match_scores[y] } if sort == :match

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

  def self.filesystem_filter(nonsafe)
    nonsafe = nonsafe.gsub(/[^a-zA-Z0-9_]/, '_')
    nonsafe = nonsafe.gsub(/_{2,}/, '_')
    nonsafe = nonsafe.gsub(/^_|_$/, '')
    return nonsafe
  end

  def self.uri_arg_filter(nonsafe)
    return URI.escape(nonsafe)
  end
  
  def self.expand_option(option, filters={}, expand_data={}, default='fs')
    expand_filters = { "fs" => self.method(:filesystem_filter), "arg" => self.method(:uri_arg_filter) }
    filters.each {|k,v| expand_filters[k] = v }
    expanded_options = option

    expanded_options.gsub!(/\{(?:(.+?):)?(.+?)\}/) do |x|
      filter = $1
      filter = default if filter == '' or filter == nil
      var = $2

      throw Exception.new("No filter called '#{filter}' when expanding option string.") if filter != nil and not expand_filters.key?(filter)
      throw Exception.new("No data called '#{var}' when expanding option string.") if not expand_data.key?(var)

      if filter
        expand_filters[filter].call(expand_data[var])
      else
        expand_data[var]
      end
    end

    return expanded_options
  end
end

