// Immunity and infinite ammo feature - only active outside of rounds

#define SET_BOOL_COOKIE(%1,%2) \
  void %1(int client, bool enabled) { \
    if (!AreClientCookiesCached(client)) return; \
    char value[2]; \
    IntToString(enabled ? 1 : 0, value, sizeof(value)); \
    SetClientCookie(client, %2, value); \
  }

#define GET_BOOL_COOKIE(%1,%2,%3) \
  bool %1(int client) { \
    char value[2]; \
    GetClientCookie(client, %2, value, sizeof(value)); \
    if (strlen(value) == 0) return false; \
    %3[client] = (StringToInt(value) != 0); \
    return true; \
  }

#define TOGGLE_CMD(%1,%2,%3,%4,%5) \
  Action %1(int client, int args) { \
    if (IsMatch()) { \
      TagChatClient(client, %2); \
      PH; \
    } \
    %3[client] = !%3[client]; \
    %4(client, %3[client]); \
    if (IsPlayerAlive(client)) { \
      TF2_RespawnPlayer(client); \
      ApplyBootsAttributes(client); \
    } \
    TagChatClient(client, %5, %3[client] ? "enabled" : "disabled"); \
    PH; \
  }

bool IsMatch() {
  bool awaitingReadyRestart = view_as<bool>(GameRules_GetProp("m_bAwaitingReadyRestart"));
  bool timerPaused          = false;
  bool timerDisabled        = false;
  bool isPostRound          = GameRules_GetRoundState() == RoundState_TeamWin;

  if (g_iCachedTimerEntity != -1 && IsValidEntity(g_iCachedTimerEntity)) {
    timerPaused   = view_as<bool>(GetEntProp(g_iCachedTimerEntity, Prop_Send, "m_bTimerPaused"));
    timerDisabled = view_as<bool>(GetEntProp(g_iCachedTimerEntity, Prop_Send, "m_bIsDisabled"));
  }

  return !(awaitingReadyRestart || timerPaused || timerDisabled || isPostRound);
}

void SetAmmo(int client, int weapon, int ammo) {
  if (!IsValidEntity(weapon)) return;
  int offset   = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1) * 4;
  int ammotype = FindSendPropInfo("CTFPlayer", "m_iAmmo") + offset;
  SetEntData(client, ammotype, ammo, 4, true);
}

SET_BOOL_COOKIE(SetAmmoCookie, cookieInfiniteAmmo)
GET_BOOL_COOKIE(GetAmmoCookie, cookieInfiniteAmmo, g_bInfiniteAmmo)
SET_BOOL_COOKIE(SetImmunityCookie, cookieImmunity)
GET_BOOL_COOKIE(GetImmunityCookie, cookieImmunity, g_bImmunity)

TOGGLE_CMD(CImmune, "Immunity is disabled during a match.", g_bImmunity, SetImmunityCookie, "Immunity %s.")
TOGGLE_CMD(CInfAmmo, "Infinite ammo is disabled during a match.", g_bInfiniteAmmo, SetAmmoCookie, "Infinite ammo %s.")

public Action Hook_ImmunityOnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
  if (IsMatch()) PC;

  if (g_bImmunity[victim]) {
    g_bPendingHP[victim] = true;
    int health = GetClientHealth(victim);
    if (health <= damage) damage = health - 1.0;
    return Plugin_Changed;
  }

  if (attacker >= 1 && attacker <= MaxClients && g_bImmunity[attacker]) {
    if (damage > 0.0) damage = 0.0;
    return Plugin_Changed;
  }

  PC;
}

public void Hook_ImmunityOnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
  if (IsMatch()) return;

  if (g_bPendingHP[victim]) {
    g_bPendingHP[victim] = false;
    if (IsValidClient(victim) && IsPlayerAlive(victim))
      SetEntityHealth(victim, GetPlayerMaxHealthTF2(victim));
  }
}

public void OnClientPutInServer(int client) {
  g_bImmunity[client]     = false;
  g_bInfiniteAmmo[client] = false;
  g_bPendingHP[client]    = false;
  SDKHook(client, SDKHook_OnTakeDamage,     Hook_ImmunityOnTakeDamage);
  SDKHook(client, SDKHook_OnTakeDamagePost, Hook_ImmunityOnTakeDamagePost);
}
