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
  version = "2026-09-07";
  src = fetchFromGitHub {
    owner = "samber";
    repo = "cc-skills-golang";
    rev = "19a0626ae8565d27a7b7bdf59d8d99d94d7e284c";
    hash = "sha256-owdNtWmTwxzzrmS0XwU/8GKbJmDKl0uqi9VpiBhemps=";
  };
  inherit include exclude;
}
