require 'test_helper'

class MemsourceTest < Minitest::Test
  def test_that_it_has_a_version_number
    assert_not_nil ::Memsource::VERSION
  end

  def email
    @email ||= ENV['TEST_EMAIL']
  end

  def password
    @password ||= ENV['TEST_PASSWORD']
  end

  def project_name
    @project_name ||= 'Test Project'.freeze
  end

  def client_name
    @client_name ||= 'Client Name'.freeze
  end

  def user
    @user ||= auth.login(email, password)
  end

  def project
    @project ||= Memsource::Project.new(user.token)
  end

  def client
    @client ||= Memsource::Client.new(user.token)
  end

  def auth
    @auth ||= Memsource::Auth.new
  end

  def test_it_authenticates
    response = VCR.use_cassette('it_authenticates') do
      auth.login(email, password)
    end

    assert_equal email, response.user.email
    assert_not_nil response.token
  end

  def test_it_creates_projects
    response = VCR.use_cassette('it_creates_projects') do
      project.create(project_name, 'en', ['es'], client: { id: client.list.content.first.id })
    end

    assert_equal project_name, response.name
    assert_equal email, response.owner.email
  end

  def test_it_gets_projects
    response = VCR.use_cassette('it_gets_projects') do
      project.list
    end

    assert response.content.count.positive?
    assert_equal email, response.content.first.owner.email
  end

  def test_it_creates_jobs
    filename = 'upload.txt'

    response = VCR.use_cassette('it_creates_jobs') do
      project_id = project.list.content.first.id

      Memsource::Job.new(user.token).create(project_id,
        File.new('test/fixtures/upload.txt'), filename, ['es'])
    end

    assert_equal filename, response.jobs.first.filename
  end

  def test_it_creates_clients
    response = VCR.use_cassette('it_creates_clients') do
      client.create(client_name, 'GUID GOES HERE', 'Notes go here')
    end

    assert_equal client_name, response.name
  end

  def test_it_manages_sessions
    response = VCR.use_cassette('it_creates_manages_sessions') do
      session = Memsource::Session.new(email, password)

      session.projects.create(project_name, 'en', ['es'])
    end

    assert_equal project_name, response.name
    assert_equal email, response.owner.email
  end

  def test_it_gets_a_project
    id = nil
    session = VCR.use_cassette('it_gets_a_project') do
      session = Memsource::Session.new(email, password)

      id = session.projects.list.content.first.id

      session.projects.find(id)
      session
    end

    # check that it doesn't hit the url again
    response = session.projects.find(id)

    assert_equal id, response.id
  end

  def test_it_queries_projects
    response = VCR.use_cassette('it_queries_projects') do
      session = Memsource::Session.new(email, password)

      session.projects.where(name: project_name, sourceLang: 'en')
    end

    assert_equal project_name, response.first.name
  end

  def test_it_queries_projects_without_results
    response = VCR.use_cassette('it_queries_projects') do
      session = Memsource::Session.new(email, password)

      session.projects.where(name: project_name, sourceLang: 'es')
    end

    assert response.empty?
  end

  def test_it_find_by_projects
    response = VCR.use_cassette('it_queries_projects') do
      session = Memsource::Session.new(email, password)

      session.projects.find_by(name: project_name)
    end

    assert_equal project_name, response.name
  end
end
