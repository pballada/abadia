cask "abadia" do
  version "0.3.0"
  sha256 "74b62582b3cafb4e3c809b8384a4eae6406cc7c6a3d864f8c00caad7415df55f"

  url "https://github.com/pballada/abadia/releases/download/v#{version}/Abadia-macOS.zip"
  name "La abadía del crimen"
  desc "Native port of the 1987 adventure game La abadía del crimen"
  homepage "https://github.com/pballada/abadia"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :ventura"

  app "La abadia del crimen.app"

  zap trash: [
    "~/Library/Application Support/Abadia",
    "~/Library/Preferences/net.pballada.abadia.plist",
    "~/Library/Saved Application State/net.pballada.abadia.savedState",
  ]
end
