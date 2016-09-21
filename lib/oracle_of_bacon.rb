#require 'byebug'                # optional, may be helpful
require 'open-uri'              # allows open('http://...') to return body
require 'cgi'                   # for escaping URIs
require 'nokogiri'              # XML parser
require 'active_model'          # for validations

class OracleOfBacon

  class InvalidError < RuntimeError ; end
  class NetworkError < RuntimeError ; end
  class InvalidKeyError < RuntimeError ; end

  attr_accessor :from, :to
  attr_reader :api_key, :response, :uri
  
  include ActiveModel::Validations
  validates_presence_of :from
  validates_presence_of :to
  validates_presence_of :api_key
  validate :from_does_not_equal_to

  def from_does_not_equal_to
    if @from == @to
      self.errors.add(:from, 'cannot be the same as To')
    end
  end

  def initialize(api_key='')
    # your code here
    @to = "Kevin Bacon"
    @from = "Kevin Bacon"
    @api_key = api_key
  end

  def find_connections
    make_uri_from_arguments
    begin
      xml = URI.parse(uri).read
    rescue OpenURI::HTTPError 
      xml = %q{<?xml version="1.0" standalone="no"?>
<error type="unauthorized">unauthorized use of xml interface</error>}
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
      Net::ProtocolError => e
      # convert all of these into a generic OracleOfBacon::NetworkError,
      #  but keep the original error message
      # your code here
      raise OracleOfBacon::NetworkError, e.message
    end
    # your code here: create the OracleOfBacon::Response object
    response = Response.new(xml)
  end

  def make_uri_from_arguments
    # your code here: set the @uri attribute to properly-escaped URI
    # constructed from the @from, @to, @api_key arguments
    oob_uri = "http://oracleofbacon.org/cgi-bin/xml?"
    @uri = oob_uri + "p=" + @api_key + "&a=" + CGI.escape(@to) + "&b=" + CGI.escape(@from)
  end
      
  class Response
    attr_reader :type, :data

    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      parse_response
    end

    private

    def parse_response
      if ! @doc.xpath('/error').empty?
        parse_error_response
      elsif ! @doc.xpath('/spellcheck').empty?
        parse_spellcheck_response
      elsif ! @doc.xpath('/link').empty?
        parse_graph_response
      else
        parse_unknown_response
      end
    end

    def parse_error_response
     #Your code here.  Assign @type and @data
     # based on type attribute and body of the error element
      @data = @doc.xpath('//error').text
      puts @doc.xpath('//error')
      if @doc.xpath('//error').text.include? "No query received"
        @type = :badinput                #to fix***********
      end
      if @doc.xpath('//error').text.include? "no link"
        @type = :unlinkable 
      end
      if @doc.xpath('//error').text.include? "unauthorized"
        @type = :unauthorized
      end
    end

    def parse_spellcheck_response
      @type = :spellcheck
      @data = @doc.xpath('//match').map(&:text)
      #Note: map(&:text) is same as map{|n| n.text}
    end

    def parse_graph_response
      #Your code here
      graph_array = []
      actor_array = []
      movie_array = []
      @doc.xpath('//actor').each do |actor|
        actor_array << actor.inner_text
      end
      @doc.xpath('//movie').each do |movie|
        movie_array << movie.inner_text
      end
      while (actor_array.empty?) == false do
        graph_array << actor_array[0]
        actor_array.shift
        if movie_array.empty? == false
          graph_array << movie_array[0]
          movie_array.shift
        end
      end
      @data = graph_array
      @type = :graph
    end

    def parse_unknown_response
      @type = :unknown
      @data = 'Unknown response type'
    end
  end
end

