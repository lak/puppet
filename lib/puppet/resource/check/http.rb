class Puppet::Resource::Check::Http
  parameter :port => 80
  parameter :address => "127.0.0.1"
  parameter :path => '/'

  confine :feature => :http

  def check(params)
    http = Net::Http.new(params[:address], params[:port]).new
    http.get params[:path]
    return true
  rescue
    return false
  end
end
