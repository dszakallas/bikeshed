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
  version = "2026-09-29";
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "8a1541c4a3ffa5a20a5a91de0dcf3f0bab1d1ef4";
    hash = "sha256-PRBkTEGNwT73EFCvuTprzIBGiG+UGSYiaCkY7Ji13us=";
  };
  inherit include exclude;
}
