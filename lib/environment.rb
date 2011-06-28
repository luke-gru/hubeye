module Environment

ROOTDIR = File.join(File.dirname(__FILE__), "..")

LIBDIR = File.join(ROOTDIR, "lib")
BINDIR = File.join(ROOTDIR, "bin")

$:.unshift(LIBDIR) unless $:.include? LIBDIR

end
