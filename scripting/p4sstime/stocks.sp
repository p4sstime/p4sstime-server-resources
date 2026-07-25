// Color config

char gsTag[32]    = "{plugintag}[PASS]{chat}";
char gsTagSTV[32] = "{plugintag}[PASS-TV]{chat}";

// Cookie helpers
void SetBoolCookie(int client, Cookie cookie, bool value) {
  char sValue[2];
  IntToString(value ? 1 : 0, sValue, sizeof(sValue));
  SetClientCookie(client, cookie, sValue);
}

bool GetBoolCookie(int client, Cookie cookie, bool& value) {
  char sValue[2];
  GetClientCookie(client, cookie, sValue, sizeof(sValue));
  if (strlen(sValue) == 0) return false;
  value = (StringToInt(sValue) != 0);
  return true;
}

void SetIntCookie(int client, Cookie cookie, int value) {
  char sValue[2];
  IntToString(value, sValue, sizeof(sValue));
  SetClientCookie(client, cookie, sValue);
}

bool GetIntCookie(int client, Cookie cookie, int& value) {
  char sValue[2];
  GetClientCookie(client, cookie, sValue, sizeof(sValue));
  if (strlen(sValue) == 0) return false;
  value = StringToInt(sValue);
  return true;
}

public void CTagReply(int client, const char[] format, any ...) {
  char buffer[254];
  VFormat(buffer, sizeof(buffer), format, 3);
  ApplyLegacyColors(buffer, sizeof(buffer), client);
  CReplyToCommand(client, "%s %s", gsTag, buffer);
}

public void TagChatAll(const char[] format, any ...) {
  char buffer[254];

  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i)) {
      SetGlobalTransTarget(i);
      VFormat(buffer, sizeof(buffer), format, 2);
      char clientBuffer[254];
      strcopy(clientBuffer, sizeof(clientBuffer), buffer);
      ApplyLegacyColors(clientBuffer, sizeof(clientBuffer), i);
      CPrintToChat(i, "%s %s", gsTag, clientBuffer);
    }
  }
}

public void CTagChat(int client, const char[] format, any ...) {
  char buffer[254];
  VFormat(buffer, sizeof(buffer), format, 3);
  ApplyLegacyColors(buffer, sizeof(buffer), client);
  CPrintToChat(client, "%s %s", gsTag, buffer);
}

public void CNoTagChat(int client, const char[] format, any ...) {
  char buffer[254];
  VFormat(buffer, sizeof(buffer), format, 3);
  ApplyLegacyColors(buffer, sizeof(buffer), client);
  CPrintToChat(client, "%s", buffer);
}

public void TagChatSTV(const char[] format, any ...) {
  char buffer[254];
  VFormat(buffer, sizeof(buffer), format, 2);
  CPrintToSTV("%s %s", gsTagSTV, buffer);
}

public void ApplyLegacyColors(char[] buffer, int maxLength, int client) {
  if (client > 0 && arr_iClientPrefs[client].bLegacyColors) {
    ReplaceString(buffer, maxLength, "{cRed}",       "{cOldRed}");
    ReplaceString(buffer, maxLength, "{cGreen}",     "{cOldGreen}");
    ReplaceString(buffer, maxLength, "{cBlue}",      "{cOldBlue}");
    ReplaceString(buffer, maxLength, "{cTeal}",      "{cOldCyan}");
    ReplaceString(buffer, maxLength, "{cMagenta}",   "{cOldMagenta}");
    ReplaceString(buffer, maxLength, "{cOrange}",    "{cOldYellow}");
    ReplaceString(buffer, maxLength, "{cYellow}",    "{cOldYellow}");
    ReplaceString(buffer, maxLength, "{cScore}",     "{cOldScore}");
    ReplaceString(buffer, maxLength, "{cAssist}",    "{cOldAssist}");
    ReplaceString(buffer, maxLength, "{cBlock}",     "{cOldDefense}");
    ReplaceString(buffer, maxLength, "{cNeutral}",   "{cOldNeutral}");
    ReplaceString(buffer, maxLength, "{cIntercept}", "{cOldIntercept}");
    ReplaceString(buffer, maxLength, "{cSteal}",     "{cOldSteal}");
  }
}

public void DiffPrintToChatAll(const char[] format, any ...) {
  char buffer[254];
  VFormat(buffer, sizeof(buffer), format, 2);
  
  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i) && !IsFakeClient(i)) {
      char clientBuffer[254];
      strcopy(clientBuffer, sizeof(clientBuffer), buffer);
      ApplyLegacyColors(clientBuffer, sizeof(clientBuffer), i);
      CPrintToChat(i, "%s %s", gsTag, clientBuffer);
    }
  }
}

public bool IsTeam(int client1, int client2) {
  return GetClientTeam(client1) == GetClientTeam(client2);
}

stock char[] TFTeamToString(TFTeam input) {
  char string[4];
  switch (input) {
    case TFTeam_Blue: {
      string = "BLU";
    }
    case TFTeam_Red: {
      string = "RED";
    }
    case TFTeam_Spectator: {
      string = "SPC";
    }
    case TFTeam_Unassigned: {
      string = "UNA";
    }
  }
  return string;
}

stock float fmin(float x, float y) {
  if (x <= y) return x;
  else return y;
}
stock int min(int x, int y) {
  if (x <= y) return x;
  else return y;
}
stock int GetPlayerMaxHealthTF2(int client) {
  return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
}

void RegAdminCmdWithShort(const char[] name, const char[] shortName, ConCmd handler, int flags, const char[] description) {
  RegAdminCmd(name,      handler, flags, description);
  RegAdminCmd(shortName, handler, flags, description);
}

void RegConsoleCmdWithShort(const char[] name, const char[] shortName, ConCmd handler, const char[] description) {
  RegConsoleCmd(name,      handler, description);
  RegConsoleCmd(shortName, handler, description);
}

// Save- and Loadpoint data structures
#define MAXSLOTS 2

bool g_bSavepointValid = false;
float g_vSavePos[3];
float g_vSaveAng[3];
float g_vSaveVel[3];
int g_iSavedClip1[MAXSLOTS];
int g_iSavedClip2[MAXSLOTS];
int g_iSavedAmmoType[MAXSLOTS][2];
int g_iSavedAmmoCount[MAXSLOTS][2];

// Save a point
stock Action CSavepoint( int client, int args ) {
    if ( IsMatch() || !g_bSaveEnabled ) return EndCommand( client, "Saving is disabled." );
    if ( client <= 0 || client > MaxClients || !IsClientInGame( client ) ) return Plugin_Handled;
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;

    GetClientAbsOrigin( client, g_vSavePos );
    GetClientEyeAngles( client, g_vSaveAng );
    GetEntPropVector( client, Prop_Data, "m_vecAbsVelocity", g_vSaveVel );

    // Save current ammo and clips for carried weapons
    for ( int s = 0; s < MAXSLOTS; s++ ) {
        g_iSavedClip1[ s ]          = -1;
        g_iSavedClip2[ s ]          = -1;
        g_iSavedAmmoType[ s ][ 0 ]  = -1;
        g_iSavedAmmoType[ s ][ 1 ]  = -1;
        g_iSavedAmmoCount[ s ][ 0 ] = 0;
        g_iSavedAmmoCount[ s ][ 1 ] = 0;

        int wep                     = GetPlayerWeaponSlot( client, s );
        if ( wep != -1 ) {
            g_iSavedClip1[ s ]         = GetEntProp( wep, Prop_Send, "m_iClip1" );
            g_iSavedClip2[ s ]         = GetEntProp( wep, Prop_Send, "m_iClip2" );

            int at1                    = GetEntProp( wep, Prop_Send, "m_iPrimaryAmmoType" );
            int at2                    = GetEntProp( wep, Prop_Send, "m_iSecondaryAmmoType" );
            g_iSavedAmmoType[ s ][ 0 ] = at1;
            g_iSavedAmmoType[ s ][ 1 ] = at2;
            if ( at1 >= 0 ) g_iSavedAmmoCount[ s ][ 0 ] = GetEntProp( client, Prop_Send, "m_iAmmo", _, at1 );
            if ( at2 >= 0 ) g_iSavedAmmoCount[ s ][ 1 ] = GetEntProp( client, Prop_Send, "m_iAmmo", _, at2 );
        }
    }
    g_bSavepointValid = true;

    EndCommand( client, "Location saved!" );
    return Plugin_Handled;
}

// Load saved point
stock Action CLoadpoint( int client, int args ) {
    if ( IsMatch() || !g_bSaveEnabled ) return EndCommand( client, "Loading is disabled." );
    if ( !IsValidClientAlive( client ) ) return Plugin_Handled;
    if ( args != 0 ) return EndCommand( client, "Usage: sm_load" );
    if ( !g_bSavepointValid ) return EndCommand( client, "No savepoint set yet." );

    TeleportEntity( client, g_vSavePos, g_vSaveAng, g_vSaveVel );

    // Restore ammo and clips for current carried weapons
    for ( int s = 0; s < MAXSLOTS; s++ ) {
        int wep = GetPlayerWeaponSlot( client, s );
        if ( wep != -1 ) {
            if ( g_iSavedClip1[ s ] >= 0 ) SetEntProp( wep, Prop_Send, "m_iClip1", g_iSavedClip1[ s ] );
            if ( g_iSavedClip2[ s ] >= 0 ) SetEntProp( wep, Prop_Send, "m_iClip2", g_iSavedClip2[ s ] );
        }

        // Set reserve ammo by ammo types
        int at1 = g_iSavedAmmoType[ s ][ 0 ];
        int at2 = g_iSavedAmmoType[ s ][ 1 ];
        if ( at1 >= 0 ) SetEntProp( client, Prop_Send, "m_iAmmo", g_iSavedAmmoCount[ s ][ 0 ], _, at1 );
        if ( at2 >= 0 ) SetEntProp( client, Prop_Send, "m_iAmmo", g_iSavedAmmoCount[ s ][ 1 ], _, at2 );
    }
    return Plugin_Handled;
}

// Check if a valid savepoint is saved
stock bool IsSavepointValid() {
  return g_bSavepointValid;
}

// Clear the savepoint
stock void ClearSavepoint() {
  g_bSavepointValid = false;
}

// Sends a message to the client and returns PH
stock Action EndCommand( int client, const char[] format, any... ) {
    char buffer[ 254 ];
    VFormat( buffer, sizeof( buffer ), format, 3 );
    ReplyToCommand( client, "%s", buffer );
    return Plugin_Handled;
}

// Checks if a client in-game, connected, not fake, in a valid team, and alive
bool IsValidClientAlive( int client ) {
    return IsValidClient( client ) && IsPlayerAlive( client );
}