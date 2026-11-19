{
  fetchFromGitHub,
  mkSkill,
  include ? [
    "golang-benchmark"
    "golang-cli"
    "golang-code-style"
    "golang-concurrency"
    "golang-context"
    "golang-data-structures"
    "golang-database"
    "golang-design-patterns"
    "golang-error-handling"
    "golang-observability"
    "golang-how-to"
    "golang-spf13-cobra"
    "golang-spf13-viper"
    "golang-swagger"
    "golang-testing"
  ],
  exclude ? null,
}:
mkSkill {
  name = "cc-skills-golang";
  version = "2026-11-08";
  src = fetchFromGitHub {
    owner = "samber";
    repo = "cc-skills-golang";
    rev = "d68d80aec298e1b74b37c2a472c002b5217248b3";
    hash = "sha256-Kc3OXcnaFjo+4rcH7AiBg0tJcVqXAnQvJv+pfuHETMw=";
  };
  inherit include exclude;
}
