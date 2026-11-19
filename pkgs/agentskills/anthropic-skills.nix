{
  fetchFromGitHub,
  mkSkill,
  include ? [
    "pptx"
    "pdf"
    "docx"
    "xlsx"
    "mcp-builder"
    "skill-creator"
  ],
  exclude ? null,
}:
mkSkill {
  name = "anthropic-skills";
  version = "2026-11-16";
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "e4bb5d960d87126ff3b3a8af1a104b7db67560ba";
    hash = "sha256-Gr9LatjawHHK9uKpoclWoiDHZ0NTpP3/4Pmeatl8p/Q=";
  };
  inherit include exclude;
}
