cask "lumiterm" do
  version "1.9.0"
  sha256 "eb14ee1453c3aeea1f4417576610d8f99cc271bc7699abad8a38b6383be955b2"

  url "https://github.com/ayov33/LumiTerm/releases/download/v#{version}/LumiTerm-macos.zip"
  name "LumiTerm"
  desc "Lightweight floating terminal for macOS"
  homepage "https://github.com/ayov33/LumiTerm"

  depends_on macos: ">= :ventura"

  app "LumiTerm.app"

  zap trash: [
    "~/Library/Preferences/com.ayov33.lumiterm.plist",
  ]
end
