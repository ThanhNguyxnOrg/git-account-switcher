class Gswitch < Formula
  desc "Fast multi-account GitHub and Git identity switcher"
  homepage "https://github.com/ThanhNguyxnOrg/git-account-switcher"
  url "https://github.com/ThanhNguyxnOrg/git-account-switcher/releases/download/v1.0.0/gswitch-v1.0.0.tar.gz"
  sha256 "56b00f798a454e414be1970a47ef9901245690a6aa2f73242f4e978a5dad4482"
  license "MIT"
  def install
    bin.install "bin/git-account-switcher", "bin/gswitch", "bin/switch-git"
  end
end
