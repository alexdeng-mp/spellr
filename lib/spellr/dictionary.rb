# frozen_string_literal: true

require 'pathname'
require 'net/http'
require 'set'

module Spellr
  class Dictionary
    DEFAULT_DIR = Pathname.new(__FILE__).parent.parent.parent.join('dictionaries')

    include Enumerable

    attr_accessor :download_required, :downloader, :file, :name, :only, :only_hashbangs
    alias_method :download_required?, :download_required

    def initialize(file)
      @file = Pathname.new(file).expand_path
      @name = @file.basename('.*').to_s
      @download_options = {}
      @only = []
      @only_hashbangs = []
    end

    def each(&block)
      download if !file.exist? && download_required?

      file.each_line(&block)
    end

    def file_list
      @file_list ||= Spellr::FileList.glob(*only).sort
    end

    def include?(term)
      term = term.to_s.downcase + "\n"
      to_set.include?(term)
    end

    def to_set
      @to_set ||= super
    end

    def lazy_download(**download_options)
      self.downloader = Spellr::SCOWLDownloader.new(download_options)
      self.download_required = true
    end

    def download(**download_options)
      self.downloader ||= Spellr::SCOWLDownloader.new(download_options)
      self.download_required = false
      downloader.download(to: file)
      self.downloader = nil

      process_wordlist
    end

    private

    def process_wordlist # rubocop:disable Metrics/AbcSize
      wordlist = file.each_line.map do |line|
        line = line.strip.downcase.sub(/'s$/, '')
        next unless line.length >= Spellr.config.minimum_dictionary_entry_length

        line
      end.compact.uniq.sort

      file.write(wordlist.join("\n") + "\n")
    end
  end
end
