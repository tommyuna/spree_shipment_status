module Retriable
  # This will catch any exception and retry twice (three tries total):
  #   with_retries { ... }
  #
  # This will catch any exception and retry four times (five tries total):
  #   with_retries(:limit => 5) { ... }
  #
  # This will catch a specific exception and retry once (two tries total):
  #   with_retries(Some::Error, :limit => 2) { ... }
  #
  # You can also sleep inbetween tries. This is helpful if you're hoping
  # that some external service recovers from its issues.
  #   with_retries(Service::Error, :sleep => 1) { ... }
  #
  def with_retries(*args, &block)
    options = args.extract_options!
    exceptions = args

    options[:limit] ||= 3
    options[:sleep] ||= 0
    exceptions = [Exception] if exceptions.empty?

    retried = 0
    begin
      yield
    rescue *exceptions => e
      if retried + 1 < options[:limit]
        retried += 1
        sleep options[:sleep]
        retry
      else
        raise e
      end
    end
  end
end

require 'nokogiri'
include Retriable

module Spree
  class ScraperBase
    attr_reader :login_info, :addresses, :selectors

    def initialize
      shipping_config = YAML.load_file("#{Rails.root}/config/shipping_update.yml")
      @config = shipping_config["#{ENV['RAILS_ENV'] || "development"}"]
      @login_info = {}
      @korean_name_convert = YAML.load_file("#{Rails.root}/config/korean_name_convert.yml")
    end

    def get_single_text html_doc, selector
      html_doc.at_css(selector)
    end

    def get_multiple_text html_doc, selector
      html_doc.css(selector)
    end

    def convert_korean_name name
      name.each_char.inject([]) do |ary, ch|
        ary << @korean_name_convert[ch]
      end.compact.join(' ')
    end

    private
    def get_config args
      tmp = @config
      args.split('.').each do |arg|
        tmp = tmp[arg]
      end
      tmp
    end
  end
end
