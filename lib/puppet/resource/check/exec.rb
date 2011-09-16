class Puppet::Resource::Check::Exec
  parameter :command

  def check(params)
    result = Puppet::Util.execute(params[:command])
    debug "Check of '#{params[:command]} returned '#{result}'"
    return true
  rescue
    return false
  end
end
