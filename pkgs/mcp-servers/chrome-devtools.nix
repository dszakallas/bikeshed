{ nodejs }:
{
  type = "stdio";
  command = "${nodejs}/bin/npx";
  args = [
    "-y"
    "chrome-devtools-mcp@latest"
    "--no-usage-statistics"
    "--no-performance-crux"
  ];
  env = { };
}
