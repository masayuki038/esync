require 'rubygems'
require 'win32/changenotify'
require 'date'
require 'md5'
require 'logger'
require 'win32/dir'

include Win32

class EsyncObserver

  def initialize
    @srcdir = 'C:\Users\masayuki\work\ruby\test'
    @destdir = 'C:\Users\masayuki\work\ruby\test2'
    @backupdir = 'C:\Users\masayuki\work\ruby\backup'
    @table = {}
    #@logger = Logger.new('C:\Users\masayuki\work\ruby\esync.log')
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG
    @sync_at_init = true
    @logger.debug "initialize end."
  end

  def start

    trap("INT") do
      print "trap INT."
      @observer.exit
      exit
    end

    @logger.debug "service_main start."
    @observer = Thread.new do
      start_observe
    end

    @logger.debug "started to observe."

    @observer.join

    @logger.debug "service_main end."
  end

private
  def start_observe
    begin
      sync if @sync_at_init
      while(true) do
        @logger.debug "."
        remain = @table.keys
        Dir.entries(@srcdir).each do |b|
          next if(b == '.' || b == '..')
          f = @srcdir + '/' + b
          t = @table[f]
          if(t)
            remain.delete(f)
            if(t < File.mtime(f))
             @logger.debug "modified #{f}."
             copy(f) 
              @table[f] = File.mtime(f)
            end
          else
            @logger.debug "added #{f}."
            copy(f)
            @table[f] = File.mtime(f)
          end
        end
        remain.each do |f|
          removed(f)
          @table.delete(f)
        end
        sleep(5)
      end
    rescue => ex
      @logger.fatal ex
    end
  end

  def removed(f)
    dest = get_dest_filename(f)
    FileUtils.remove_file(dest)
    @logger.debug "#{dest} has removed."
  end

  def copy(f)
    @logger.debug "copy #{f}"
    dest = get_dest_filename(f)
    FileUtils.cp(f, dest)
    @logger.debug "#{dest} has copied."
  end

  def get_dest_filename(file_name)
    @destdir + '/' + File.basename(file_name)
  end

  def sync
    Dir.mkdir(@backupdir) unless FileTest::directory?(@backupdir)
    remain = Dir.entries(@destdir)
    remain.delete('.')
    remain.delete('..')

    Dir.entries(@srcdir).each do |b|
      next if(b == '.' || b == '..')
      src = @srcdir + '/' + b
      dest = get_dest_filename(src)
      remain.delete(b)
      @table[src] = File.mtime(src)
      next if(FileTest.file?(dest) && File.mtime(dest) >= File.mtime(src))
      copy(src)
    end

    remain.each do |f|
      dest = get_dest_filename(f)
      @logger.debug "move from #{dest} to #{@backupdir}."
      FileUtils.move([dest], @backupdir)
    end
  end
end
EsyncObserver.new.start