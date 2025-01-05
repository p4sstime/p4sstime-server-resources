stock char[] TFTeamToString(TFTeam input)
{
  char string[4];
  switch (input)
  {
    case TFTeam_Blue:
    {
      string = "BLU";
    }
    case TFTeam_Red:
    {
      string = "RED";
    }
    case TFTeam_Spectator:
    {
      string = "SPC";
    }
    case TFTeam_Unassigned:
    {
      string = "UNA";
    }
  }
  return string;
}

stock void FormatServersidePluginMessage(char[] outBuf, int maxLength, const char[] format, any...)
{
  char interimBuf[512];
  VFormat(interimBuf, sizeof(interimBuf), format, 4);
  Format(outBuf, maxLength, "\x07ffff00[PASS] %s", interimBuf);
}