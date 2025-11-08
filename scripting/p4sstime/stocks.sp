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

stock float fmin(float x, float y)
{
  if (x <= y) return x;
  else return y;
}
stock int min(int x, int y)
{
  if (x <= y) return x;
  else return y;
}
stock int GetPlayerMaxHealthTF2(int client)
{
  return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
}
stock void FormatServersidePluginMessage(char[] outBuf, int maxLength, const char[] format, any...)
{
  char interimBuf[512];
  VFormat(interimBuf, sizeof(interimBuf), format, 4);
  Format(outBuf, maxLength, "\x07ffff00[PASS] %s", interimBuf);
}