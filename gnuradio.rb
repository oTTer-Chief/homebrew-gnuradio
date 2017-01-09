class Gnuradio < Formula
  desc "SDK providing the signal processing runtime and processing blocks"
  homepage "http://gnuradio.org/"
  url "http://gnuradio.org/releases/gnuradio/gnuradio-3.7.10.1.tar.gz"
  sha256 "63d7b65cc4abe22f47b8f41caaf7370a0a502b91e36e29901ba03e8838ab4937"
  head "https://github.com/gnuradio/gnuradio.git"
  revision 6

  # Fixes linkage of python (swig) bindings directly to python
  # https://github.com/gnuradio/gnuradio/pull/1146
  patch do
    url "https://github.com/gnuradio/gnuradio/pull/1146.patch"
    sha256 "385b62cc46ff07696f7ff4ff89bbb4891909947027f9712be040937d477f6d81"
  end

  option :universal
  option "with-documentation", "Build with documentation"

  depends_on "pkg-config" => :build

  depends_on :python if MacOS.version <= :snow_leopard
  depends_on "boost"
  depends_on "cppunit"
  depends_on "fftw"
  depends_on "gsl"
  depends_on "zeromq"
  depends_on "swig"
  depends_on "cmake" => :build

  # For documentation
  depends_on "doxygen" => :build
  depends_on "sphinx-doc" => :build

  depends_on "uhd" => :recommended
  depends_on "sdl" => :recommended
  depends_on "jack" => :recommended
  depends_on "portaudio" => :recommended
  depends_on "pygtk" => :recommended
  depends_on "wxpython" => :recommended

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
                            gr-dtv gr-atsc gr-trellis gr-zeromq gr-utils python]
    enabled_components << "gr-wavelet"
    enabled_components << "gr-video-sdl" if build.with? "sdl"
    enabled_components << "gr-uhd" if build.with? "uhd"
    enabled_components << "grc" if build.with? "pygtk"
    enabled_components << "gr-wxgui" if build.with? "wxpython"
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
    system("#{bin}/gnuradio-config-info -v")

    (testpath/"test.py").write <<-EOS.undent
        from gnuradio import blocks
        from gnuradio import gr

        class top_block(gr.top_block):
            def __init__(self):
                gr.top_block.__init__(self, "Top Block")
                self.samp_rate = 32000
                s = gr.sizeof_gr_complex
                self.blocks_null_source_0 = blocks.null_source(s)
                self.blocks_null_sink_0 = blocks.null_sink(s)
                self.blocks_head_0 = blocks.head(s, 1024)
                self.connect((self.blocks_head_0, 0), (self.blocks_null_sink_0, 0))
                self.connect((self.blocks_null_source_0, 0), (self.blocks_head_0, 0))

        def main(top_block_cls=top_block, options=None):
            tb = top_block_cls()
            tb.start()
            tb.wait()

        main()
    EOS
    system "python", (testpath/"test.py")

    Dir.chdir(testpath) do
      system "gr_modtool", "newmod", "test"
      Dir.chdir("gr-test") do
        system "#{bin}/gr_modtool", "add", "-t", "general", "test_ff", "-l",
               "python", "-y", "--argument-list=''", "--add-python-qa"
      end
    end
  end
end
