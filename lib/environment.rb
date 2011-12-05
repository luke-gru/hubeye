module Environment

ROOTDIR = File.expand_path(File.dirname(__FILE__) + '/..')

LIBDIR = File.join(ROOTDIR, "lib")
BINDIR = File.join(ROOTDIR, "bin")

$:.unshift(LIBDIR) unless $:.include? LIBDIR

end

