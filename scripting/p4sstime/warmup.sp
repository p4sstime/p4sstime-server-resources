// Immunity and infinite ammo feature - only active outside of rounds

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

Action CImmune(int client, int args) {
  if (IsMatch()) {
    TagChatClient(client, "Immunity is disabled during a match.");
    PH;
  }
  g_bImmunity[client] = !g_bImmunity[client];
  SetBoolCookie(client, cookieImmunity, g_bImmunity[client]);
  if (IsPlayerAlive(client)) {
    TF2_RespawnPlayer(client);
    ApplyBootsAttributes(client);
  }
  TagChatClient(client, "Immunity %s.", g_bImmunity[client] ? "enabled" : "disabled");
  PH;
}

Action CInfAmmo(int client, int args) {
  if (IsMatch()) {
    TagChatClient(client, "Infinite ammo is disabled during a match.");
    PH;
  }
  g_bInfiniteAmmo[client] = !g_bInfiniteAmmo[client];
  SetBoolCookie(client, cookieInfiniteAmmo, g_bInfiniteAmmo[client]);
  if (IsPlayerAlive(client)) {
    TF2_RespawnPlayer(client);
    ApplyBootsAttributes(client);
  }
  TagChatClient(client, "Infinite ammo %s.", g_bInfiniteAmmo[client] ? "enabled" : "disabled");
  PH;
}

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
