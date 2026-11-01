class Gswitch < Formula
  desc "Fast multi-account GitHub and Git identity switcher"
  homepage "https://github.com/ThanhNguyxnOrg/git-account-switcher"
  url "https://github.com/ThanhNguyxnOrg/git-account-switcher/releases/download/v1.0.1/gswitch-v1.0.1.tar.gz"
  sha256 "c91d7b66eec1edf2459f1298ef40d87da5138b97a35e8d267b603cb9cd769e55"
  license "MIT"
  def install
    bin.install "bin/git-account-switcher", "bin/gswitch", "bin/switch-git"
  end
end
