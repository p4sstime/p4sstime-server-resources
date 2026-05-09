// This file relates to all demoman rebalancing features

void ApplyDemoResistance(int client) {
  if (!IsValidClient(client)) return;

  TFClassType playerClass = TF2_GetPlayerClass(client);
  float desiredValue = 0.0;
  bool shouldApply = false;

  // When demo resistance is disabled, apply blast vulnerability (25% more damage)
  // When enabled, remove the attribute so shield works normally
  if (playerClass == TFClass_DemoMan) {
    if (!g_bDemoResistEnabled) {
      desiredValue = 1.25;
      shouldApply = true;
    }
  }

  if (shouldApply) {
    if (!g_bDemoResistApplied[client] || g_fCurrentDemoResistValue[client] != desiredValue) {
      SetAttributeByName(client, "dmg taken from blast reduced", desiredValue);
      g_fCurrentDemoResistValue[client] = desiredValue;
      g_bDemoResistApplied[client] = true;
    }
  } else {
    if (g_bDemoResistApplied[client]) {
      RemoveAttributeByName(client, "dmg taken from blast reduced");
      g_fCurrentDemoResistValue[client] = 0.0;
      g_bDemoResistApplied[client] = false;
    }
  }
}

void ClearBootsState(int client) {
  g_bBootsAttributesApplied[client] = false;
  g_fCurrentBootsChargeTurn[client] = 0.0;
  g_fCurrentBootsMaxHealth[client] = 0.0;
  g_fCurrentBootsKillRefill[client] = 0.0;
  g_fCurrentBootsMoveSpeed[client] = 0.0;
}

void ApplyBootsAttributes(int client) {
  if (!IsValidClient(client) || !IsPlayerAlive(client)) {
    if (g_bBootsAttributesApplied[client]) ClearBootsState(client);
    return;
  }

  if (TF2_GetPlayerClass(client) != TFClass_DemoMan) {
    if (g_bBootsAttributesApplied[client]) ClearBootsState(client);
    return;
  }

  // Find Demoman boots (Ali Baba's Wee Booties = 405, Bootlegger = 608)
  int bootsEntity = -1;
  int entity = -1;
  while ((entity = FindEntityByClassname(entity, "tf_wearable")) != -1) {
    if (!IsValidEntity(entity)) continue;
    if (GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") != client) continue;
    int defIndex = GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
    if (defIndex == 405 || defIndex == 608) {
      bootsEntity = entity;
      break;
    }
  }

  if (bootsEntity == -1) {
    if (g_bBootsAttributesApplied[client]) ClearBootsState(client);
    return;
  }

  float chargeTurn = cvBootsChargeTurn.FloatValue;
  float maxHealth  = cvBootsMaxHealth.FloatValue;
  float killRefill = cvBootsKillRefill.FloatValue;
  float moveSpeed  = cvBootsMoveSpeed.FloatValue;

  if (!g_bBootsAttributesApplied[client]
    || g_fCurrentBootsChargeTurn[client] != chargeTurn
    || g_fCurrentBootsMaxHealth[client] != maxHealth
    || g_fCurrentBootsKillRefill[client] != killRefill
    || g_fCurrentBootsMoveSpeed[client] != moveSpeed) {
    SetAttributeByName(bootsEntity, "mult charge turn control", chargeTurn);
    SetAttributeByName(bootsEntity, "max health additive bonus", maxHealth);
    SetAttributeByName(bootsEntity, "kill refills meter", killRefill);
    SetAttributeByName(bootsEntity, "move speed bonus shield required", moveSpeed);

    g_fCurrentBootsChargeTurn[client] = chargeTurn;
    g_fCurrentBootsMaxHealth[client]  = maxHealth;
    g_fCurrentBootsKillRefill[client] = killRefill;
    g_fCurrentBootsMoveSpeed[client]  = moveSpeed;
    g_bBootsAttributesApplied[client] = true;
  }
}

void ClearDemoClientState(int client) {
  g_bDemoResistApplied[client] = false;
  g_fCurrentDemoResistValue[client] = 0.0;
  ClearBootsState(client);
}

Action CToggleDemoResist(int client, int args) {
  if (args != 1) {
    CTagReply(client, "Usage: sm_pt_demoresist <0|1>");
    PH;
  }

  int value = GetCmdArgInt(1);
  if (value != 0 && value != 1) {
    CTagReply(client, "Usage: sm_pt_demoresist <0|1>");
    PH;
  }

  g_bDemoResistEnabled = (value != 0);

  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i))
      ApplyDemoResistance(i);
  }

  CTagReply(client, "Demo blast resistance %s", g_bDemoResistEnabled ? "{pfgreen}enabled" : "{pfred}disabled");
  PH;
}
