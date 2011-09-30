require 'puppet/provider'

Puppet::Type.type(:yumrepo).provide :plain do
    self.filetype = Puppet::Util::FileType.filetype(:flat)

    class << self
        attr_accessor :filetype
        # The writer is only used for testing, there should be no need
        # to change yumconf or inifile in any other context
        attr_accessor :yumconf
        attr_writer :inifile
    end

    @inifile = nil

    @yumconf = "/etc/yum.conf"

    # Where to put files for brand new sections
    @defaultrepodir = nil

    def self.instances
        l = []
        check = validproperties
        clear
        inifile.each_section do |s|
            next if s.name == "main"
            obj = create(:name => s.name, :check => check)
            current_values = obj.retrieve
            obj.eachproperty do |property|
                if current_values[property].nil?
                    obj.delete(property.name)
                else
                    property.should = current_values[property]
                end
            end
            obj.delete(:check)
            l << obj
        end
        l
    end

    # Return the Puppet::Util::IniConfig::File for the whole yum config
    def self.inifile
        if @inifile.nil?
            @inifile = read()
            main = @inifile['main']
            if main.nil?
                raise Puppet::Error, "File #{yumconf} does not contain a main section"
            end
            reposdir = main['reposdir']
            reposdir ||= "/etc/yum.repos.d, /etc/yum/repos.d"
            reposdir.gsub!(/[\n,]/, " ")
            reposdir.split.each do |dir|
                Dir::glob("#{dir}/*.repo").each do |file|
                    if File.file?(file)
                        @inifile.read(file)
                    end
                end
            end
            reposdir.split.each do |dir|
                if File::directory?(dir) && File::writable?(dir)
                    @defaultrepodir = dir
                    break
                end
            end
        end
        return @inifile
    end

    # Parse the yum config files. Only exposed for the tests
    # Non-test code should use self.inifile to get at the
    # underlying file
    def self.read
        result = Puppet::Util::IniConfig::File.new()
        result.read(yumconf)
        main = result['main']
        if main.nil?
            raise Puppet::Error, "File #{yumconf} does not contain a main section"
        end
        reposdir = main['reposdir']
        reposdir ||= "/etc/yum.repos.d, /etc/yum/repos.d"
        reposdir.gsub!(/[\n,]/, " ")
        reposdir.split.each do |dir|
            Dir::glob("#{dir}/*.repo").each do |file|
                if File.file?(file)
                    result.read(file)
                end
            end
        end
        if @defaultrepodir.nil?
            reposdir.split.each do |dir|
                if File::directory?(dir) && File::writable?(dir)
                    @defaultrepodir = dir
                    break
                end
            end
        end
        return result
    end

    # Return the Puppet::Util::IniConfig::Section with name NAME
    # from the yum config
    def self.section(name)
        result = inifile[name]
        if result.nil?
            # Brand new section
            path = yumconf
            unless @defaultrepodir.nil?
                path = File::join(@defaultrepodir, "#{name}.repo")
            end
            Puppet::info "create new repo #{name} in file #{path}"
            result = inifile.add_section(name, path)
        end
        return result
    end

    # Store all modifications back to disk
    def self.store
        inifile.store
        unless Puppet[:noop]
            target_mode = 0644 # FIXME: should be configurable
            inifile.each_file do |file|
                current_mode = File.stat(file).mode & 0777
                unless current_mode == target_mode
                    Puppet::info "changing mode of #{file} from %03o to %03o" % [current_mode, target_mode]
                    File.chmod(target_mode, file)
                end
            end
        end
    end

    # This is only used during testing.
    def self.clear
        @inifile = nil
        @yumconf = "/etc/yum.conf"
        @defaultrepodir = nil
    end

    # Return the Puppet::Util::IniConfig::Section for this yumrepo resource
    def section
        self.class.section(self[:name])
    end

    # Store modifications to this yumrepo resource back to disk
    def store
        self.class.store
    end
end
