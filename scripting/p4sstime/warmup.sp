// Immunity and infinite ammo

// Game state machine
enum GameState {
  STATE_WAITING,
  STATE_COUNTDOWN,
  STATE_GAME_START,
  STATE_ROUND_ACTIVE,
  STATE_ROUND_FINISHED,
  STATE_GAME_FINISHED
};

GameState g_iGameState       = STATE_WAITING;

Action EGameState_RoundRestartSeconds(Event event, const char[] name, bool dontBroadcast) {
  g_iGameState = STATE_COUNTDOWN;
  return Plugin_Continue;
}

Action EGameState_RestartRound(Event event, const char[] name, bool dontBroadcast) {
  g_iGameState = STATE_GAME_START;
  return Plugin_Continue;
}

Action EGameState_MapTimeRemaining(Event event, const char[] name, bool dontBroadcast) {
  g_iGameState = STATE_GAME_START;
  return Plugin_Continue;
}

Action EGameState_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  g_iGameState = STATE_GAME_START;
  return Plugin_Continue;
}

Action EGameState_GameOver(Event event, const char[] name, bool dontBroadcast) {
  g_iGameState = STATE_GAME_FINISHED;
  return Plugin_Continue;
}

void SetGameState(GameState state) {
  g_iGameState = state;
}

void OnGameStateRoundActive() {
  g_iGameState = STATE_ROUND_ACTIVE;
}

void OnGameStateRoundWin() {
  g_iGameState = STATE_ROUND_FINISHED;
}

bool IsMatch() {
  if (g_iGameState != STATE_WAITING) {
    return g_iGameState == STATE_GAME_START
        || g_iGameState == STATE_ROUND_ACTIVE
        || g_iGameState == STATE_ROUND_FINISHED;
  }

  bool awaitingReadyRestart = view_as<bool>(GameRules_GetProp("m_bAwaitingReadyRestart"));
  bool timerPaused          = false;
  bool timerDisabled        = false;
  bool isPostRound          = GameRules_GetRoundState() == RoundState_TeamWin;

  int timer = GetOrFindTimer();
  if (timer != -1) {
    timerPaused   = view_as<bool>(GetEntProp(timer, Prop_Send, "m_bTimerPaused"));
    timerDisabled = view_as<bool>(GetEntProp(timer, Prop_Send, "m_bIsDisabled"));
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
    CTagChat(client, "Immunity is disabled during a match.");
    return Plugin_Handled;
  }
  arr_iClientPrefs[client].bImmunity = !arr_iClientPrefs[client].bImmunity;
  SetBoolCookie(client, ck_bImmunity, arr_iClientPrefs[client].bImmunity);
  if (IsPlayerAlive(client)) {
    TF2_RespawnPlayer(client);
    ApplyBootsAttributes(client);
  }
  CTagChat(client, "Immunity %s.", arr_iClientPrefs[client].bImmunity ? "enabled" : "disabled");
  return Plugin_Handled;
}

Action CInfAmmo(int client, int args) {
  if (IsMatch()) {
    CTagChat(client, "Infinite ammo is disabled during a match.");
    return Plugin_Handled;
  }
  arr_iClientPrefs[client].bInfAmmo = !arr_iClientPrefs[client].bInfAmmo;
  SetBoolCookie(client, ck_bInfAmmo, arr_iClientPrefs[client].bInfAmmo);
  if (IsPlayerAlive(client)) {
    TF2_RespawnPlayer(client);
    ApplyBootsAttributes(client);
  }
  CTagChat(client, "Infinite ammo %s.", arr_iClientPrefs[client].bInfAmmo ? "enabled" : "disabled");
  return Plugin_Handled;
}

public Action Hook_ImmunityOnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
  if (IsMatch()) return Plugin_Continue;

  if (arr_iClientPrefs[victim].bImmunity) {
    g_bPendingHP[victim] = true;
    int health = GetClientHealth(victim);
    if (health <= damage) damage = health - 1.0;
    return Plugin_Changed;
  }

  if (attacker >= 1 && attacker <= MaxClients && arr_iClientPrefs[attacker].bImmunity) {
    if (damage > 0.0) damage = 0.0;
    return Plugin_Changed;
  }

  return Plugin_Continue;
}

public void Hook_ImmunityOnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
  ShowAirshotMessage(victim, attacker);
  ClearDirectHit(victim);
  if (IsMatch()) return;

  if (g_bPendingHP[victim]) {
    g_bPendingHP[victim] = false;
    if (IsValidClient(victim) && IsPlayerAlive(victim))
      SetEntityHealth(victim, GetPlayerMaxHealthTF2(victim));
  }
}

public void OnClientPutInServer(int client) {
  g_bPendingHP[client]    = false;
  g_iPlyObserverMode[client] = -1;
  g_iPlyObserverTarget[client] = -1;
  ClearDirectHit(client);
  SDKHook(client, SDKHook_OnTakeDamage,     Hook_ImmunityOnTakeDamage);
  SDKHook(client, SDKHook_OnTakeDamagePost, Hook_ImmunityOnTakeDamagePost);
}
