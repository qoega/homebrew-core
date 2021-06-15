class Clickhouse < Formula
  desc "Free analytics DBMS for big data with SQL interface"
  homepage "https://clickhouse.tech"
  url "https://github.com/ClickHouse/ClickHouse/releases/download/v21.7.3.14-stable/ClickHouse_sources_with_submodules.tar.gz"
  version "21.7"
  sha256 "35b6bd81d0cd8ecd28e5d1207f8749c5aaeb831fdec7a5b20147f347c3a12757"
  license "Apache-2.0"
  head "https://github.com/ClickHouse/ClickHouse.git"
  depends_on "cmake" => :build
  depends_on "git-lfs" => :build
  depends_on "llvm" => :build
  depends_on "ninja" => :build

  on_macos do
    depends_on "llvm" => :build if DevelopmentTools.clang_build_version <= 1100
  end

  fails_with :clang do
    build 1100
    cause "Requires C++17 features not yet implemented"
  end

  def install
    if build.head?
      system "git", "lfs", "install"
      system "git", "submodule", "update", "--init", "--recursive"
    end

    mkdir_p bin
    mkdir_p "#{HOMEBREW_PREFIX}/etc/clickhouse-server"
    mkdir_p "#{var}/log/clickhouse-server"
    mkdir_p "#{var}/lib/clickhouse-server"
    mkdir_p "#{var}/run/clickhouse-server"

    inreplace "programs/server/config.xml" do |s|
      s.gsub! "<!-- <max_open_files>262144</max_open_files> -->", "<max_open_files>262144</max_open_files>"
    end
    inreplace "cmake/warnings.cmake" do |s|
      s.gsub!(/add_warning\(frame-larger-than=(\d*)\)/, "add_warning(frame-larger-than=131072)")
    end

    args = std_cmake_args
    args.delete("-DCMAKE_BUILD_TYPE=Release")
    args << "-DCMAKE_BUILD_TYPE=RelWithDebInfo"

    system "cmake", ".", *args
    system "ninja", "clickhouse-bundle"

    system "#{buildpath}/programs/clickhouse", "install",
                                               "--binary-path=#{bin}",
                                               "--config-path=#{HOMEBREW_PREFIX}/etc/clickhouse-server",
                                               "--log-path=#{var}/log/clickhouse-server",
                                               "--data-path=#{var}/lib/clickhouse-server",
                                               "--pid-path=#{var}/run/clickhouse-server"
  end

  service do
    run [opt_bin/"clickhouse-server", "--config-file=#{etc}/clickhouse-server/config.xml"]
    keep_alive true
    error_log_path var/"log/clickhouse-server/clickhouse-server.err"
    log_path var/"log/clickhouse-server/clickhouse-server.log"
  end

  test do
    system "#{bin}/clickhouse-client", "--version"
    query = "SELECT sum(number) FROM (SELECT * FROM system.numbers LIMIT 10000000)"
    assert_equal "49999995000000", shell_output("#{bin}/clickhouse-local -S 'number UInt64' -q '#{query}'").chomp
  end
end
