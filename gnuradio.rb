class Gnuradio < Formula
  desc "SDK providing the signal processing runtime and processing blocks"
  homepage "https://gnuradio.squarespace.com/"
  url "https://gnuradio.org/releases/gnuradio/gnuradio-3.7.9.1.tar.gz"
  sha256 "9c06f0f1ec14113203e0486fd526dd46ecef216dfe42f12d78d9b781b1ef967e"
  revision 1

  bottle do
    rebuild 1
    sha256 "2cbc22df1411ef7090bd43cbec10dbb23ee16439ed8bb0e10a2b144455237e51" => :sierra
    sha256 "187f22d812f4ba86af2d2f64e9473647b49aa2373d6688d7ecfb840374285749" => :el_capitan
    sha256 "41eb9fdae72761b7a83f284f1e7613da9e3ce916e0f98f20ad3aafe417be5a4e" => :yosemite
  end

  option :universal

  depends_on "pkg-config" => :build

  depends_on :python if MacOS.version <= :snow_leopard
  depends_on "boost"
  depends_on "cppunit"
  depends_on "fftw"
  depends_on "gsl"
  depends_on "zeromq"
  depends_on "swig" => :build

  # For documentation
  depends_on "doxygen" => :build
  depends_on "sphinx-doc" => :build

  depends_on "uhd" => :recommended
  depends_on "sdl" => :recommended
  depends_on "jack" => :recommended
  depends_on "portaudio" => :recommended
  depends_on "pygtk" => :recommended

  # gnuradio is known not to compile against CMake >3.3.2 currently.
  resource "cmake" do
    url "https://cmake.org/files/v3.3/cmake-3.3.2.tar.gz"
    sha256 "e75a178d6ebf182b048ebfe6e0657c49f0dc109779170bad7ffcb17463f2fc22"
  end

  resource "numpy" do
    url "https://pypi.python.org/packages/source/n/numpy/numpy-1.10.1.tar.gz"
    sha256 "8b9f453f29ce96a14e625100d3dcf8926301d36c5f622623bf8820e748510858"
  end

  # cheetah starts here
  resource "Markdown" do
    url "https://pypi.python.org/packages/source/M/Markdown/Markdown-2.4.tar.gz"
    sha256 "b8370fce4fbcd6b68b6b36c0fb0f4ec24d6ba37ea22988740f4701536611f1ae"
  end

  resource "Cheetah" do
    url "https://pypi.python.org/packages/source/C/Cheetah/Cheetah-2.4.4.tar.gz"
    sha256 "be308229f0c1e5e5af4f27d7ee06d90bb19e6af3059794e5fd536a6f29a9b550"
  end
  # cheetah ends here

  resource "lxml" do
    url "https://pypi.python.org/packages/source/l/lxml/lxml-2.0.tar.gz"
    sha256 "062e6dbebcbe738eaa6e6298fe38b1ddf355dbe67a9f76c67a79fcef67468c5b"
  end

  resource "cppzmq" do
    url "https://github.com/zeromq/cppzmq/raw/a4459abdd1d70fd980f9c166d73da71fe9762e0b/zmq.hpp"
    sha256 "f042d4d66e2a58bd951a3eaf108303e862fad2975693bebf493931df9cd251a5"
  end

  def install
    ENV["CHEETAH_INSTALL_WITHOUT_SETUPTOOLS"] = "1"
    ENV.prepend_create_path "PYTHONPATH", libexec/"vendor/lib/python2.7/site-packages"

    resource("cmake").stage do
      args = %W[
        --prefix=#{buildpath}/cmake
        --no-system-libs
        --parallel=#{ENV.make_jobs}
        --datadir=/share/cmake
        --docdir=/share/doc/cmake
        --mandir=/share/man
        --system-zlib
        --system-bzip2
      ]

      # https://github.com/Homebrew/homebrew/issues/45989
      if MacOS.version <= :lion
        args << "--no-system-curl"
      else
        args << "--system-curl"
      end

      system "./bootstrap", *args
      system "make"
      system "make", "install"
    end

    ENV.prepend_path "PATH", buildpath/"cmake/bin"

    res = %w[Markdown Cheetah lxml numpy]
    res.each do |r|
      resource(r).stage do
        system "python", *Language::Python.setup_install_args(libexec/"vendor")
      end
    end

    resource("cppzmq").stage include.to_s

    args = std_cmake_args

    if build.universal?
      ENV.universal_binary
      args << "-DCMAKE_OSX_ARCHITECTURES=#{Hardware::CPU.universal_archs.as_cmake_arch_flags}"
    end

    args << "-DENABLE_DEFAULT=OFF"
    enabled_components = %w[gr-analog gr-fft volk gr-filter gnuradio-runtime
                            gr-blocks testing gr-pager gr-noaa gr-channels
                            gr-audio gr-fcd gr-vocoder gr-fec gr-digital
                            gr-dtv gr-atsc gr-trellis gr-zeromq python]
    enabled_components << "gr-wavelet"
    enabled_components << "gr-video-sdl" if build.with? "sdl"
    enabled_components << "gr-uhd" if build.with? "uhd"
    enabled_components << "grc" if build.with? "pygtk"
    enabled_components += %w[doxygen sphinx] if build.with? "documentation"

    enabled_components.each do |c|
      args << "-DENABLE_#{c.upcase.split("-").join("_")}=ON"
    end

    mkdir "build" do
      system "cmake", "..", *args
      system "make"
      system "make", "install"
    end

    rm bin.children.reject(&:executable?)
    bin.env_script_all_files(libexec/"bin", :PYTHONPATH => ENV["PYTHONPATH"])
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/gnuradio-config-info -v").chomp
  end
end
