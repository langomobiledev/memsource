require 'memsource/version'
require 'rest-client'
require 'json/ext'
require 'ostruct'

module Memsource
  class Error < StandardError; end

  # Base class for shared methods
  class Base
    BASE = 'https://cloud.memsource.com/web/api2/v1/'.freeze
    attr_accessor :token

    def initialize(token = nil)
      self.token = token
    end

    def post(path, payload, options = {})
      url = URI.join(BASE, path).to_s

      headers = { content_type: 'application/json' }

      headers[:params] = { token: token } if token
      headers = headers.merge(options[:headers] || {})

      payload = payload&.to_json if headers[:content_type] == 'application/json'

      response = RestClient::Request.execute(
        method: :post, url: url, payload: payload, headers: headers
      )

      JSON.parse(response.body, object_class: OpenStruct)
    rescue RestClient::Exception => e
      raise Error, JSON.parse(e.response.body)['errorDescription']
    end

    def get(path, options = {})
      url = URI.join(BASE, path).to_s

      headers = { content_type: 'application/json' }

      headers[:params] = { token: token } if token
      headers = headers.merge(options[:headers] || {})

      response = RestClient::Request.execute(
        method: :get, url: url, headers: headers
      )

      JSON.parse(response.body, object_class: OpenStruct)
    rescue RestClient::Exception => e
      raise Error, JSON.parse(e.response.body)['errorDescription']
    end

    def list
      get(self.class::PATH)
    end

    def find(id)
      get("#{self.class::PATH}/#{id}")
    end
  end

  # Authenticates the user
  class Auth < Base
    PATH = 'auth/login'.freeze

    def login(username, password)
      payload = { userName: username, password: password }

      post(PATH, payload)
    end
  end

  # Manage Clients
  class Client < Base
    PATH = 'clients'.freeze

    # create a client with provided data. data should include:
    # * id: string
    # * external_id: string
    # * note: string
    # See: https://cloud.memsource.com/web/docs/api#operation/createClient
    def create(id, external_id, note, options = {})
      options[:id] = id
      options[:externalId] = external_id
      options[:note] = note
      post(PATH, options)
    end
  end

  # Allows you to list supported languages
  class Language < Base
    PATH = 'languages'.freeze
  end

  # Manage Projects
  class Project < Base
    PATH = 'projects'.freeze

    # create a project with provided data. data should include:
    # * name: string
    # * source_lang: string
    # * target_langs: array of strings of target languages using ISO-639-1 codes
    # See: https://cloud.memsource.com/web/docs/api#operation/createProject
    def create(name, source_lang, target_langs, options = {})
      options[:name] = name
      options[:sourceLang] = source_lang
      options[:targetLangs] = target_langs
      post(PATH, options)
    end
  end

  # Implementation of Memsource Jobs (a file in a Project)
  class Job < Base
    PATH = 'jobs'.freeze

    # Creates a Job in Memsource
    #
    # projectid: the id of the project in memsource
    # file: a Ruby file object or path to a file
    # options: parameters for the call. should include:
    # * targetLangs: array of strings of target languages using ISO-639-1 codes
    # * filename: the name of the file with extension
    # See: https://cloud.memsource.com/web/docs/api#operation/createJob
    def create(projectid, file, filename, target_langs, options = {})
      payload = File.open(file, 'r')
      encoding = payload.external_encoding.to_s

      options[:targetLangs] = target_langs

      headers = {
        memsource: options.to_json,
        content_type: 'application/octet-stream',
        content_disposition: "filename\*=#{encoding}''#{filename}"
      }

      path = "#{Project::PATH}/#{projectid}/#{PATH}"

      post(path, payload, headers: headers)
    end
  end

  # Tracks the user's session
  class Session
    attr_accessor :token
    def initialize(username, password)
      auth = Memsource::Auth.new.login(username, password)
      self.token = auth.token
    end

    def projects
      @projects ||= Memsource::Project.new(token)
    end

    def languages
      @languages ||= Memsource::Language.new(token)
    end

    def jobs
      @jobs ||= Memsource::Job.new(token)
    end

    def clients
      @clients ||= Memsource::Client.new(token)
    end
  end
end
